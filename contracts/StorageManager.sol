// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Pausable.sol";

/// @title StorageManager
/// @author Rinke Hendriksen <rinke@iovlabs.org>
/// @author Adam Uhlir <adam@iovlabs.org>
/// @notice Providers can offer their storage space and list their price and Consumers can take these offers
contract StorageManager is OwnableUpgradeSafe, PausableUpgradeSafe {
    using SafeMath for uint256;
    using SafeMath for uint128;
    using SafeMath for uint64;
    using SafeERC20 for IERC20;

    uint64 private constant MAX_BILLING_PERIOD = 15552000; // 6 * 30 days ~~ 6 months

    /*
    Offer represents:
     - utilizedCapacity: how much is capacity is utilized in Offer.
     - totalCapacity: total amount of mega-bytes (MB) offered.
     - billingPlansForToken: maps a whitelisted token to billing period to a billing price. When a price is 0, the period is not offered. By convention, the 0-address stands for the native currency
     - agreementRegistry: the proposed and accepted Agreement
    */
    struct Offer {
        uint64 utilizedCapacity;
        uint64 totalCapacity;
        mapping(address => mapping(uint64 => uint128)) billingPlansForToken;
        mapping(bytes32 => Agreement) agreementRegistry; // link to agreement that are accepted under this offer
    }

    /*
    Agreement represents:
     - billingPrice: price per byte that is collected per each period.
     - billingPeriod: period how often billing happens in seconds.
     - size: allocated size for the Agreement (in MB, rounded up)
     - availableFunds: funds available for the billing of the Agreement.
     - lastPayoutDate: When was the last time Provider was payed out. Zero either means non-existing or terminated Agreement.
    */
    struct Agreement {
        uint128 billingPrice;
        uint64 billingPeriod;
        uint256 availableFunds;
        uint64 size;
        uint128 lastPayoutDate;
    }

    // offerRegistry stores the open or closed Offer for provider.
    mapping(address => Offer) public offerRegistry;

    // maps the tokenAddresses which can be used with this contract. By convention, address(0) is the native token.
    mapping(address => bool) public isWhitelistedToken;

    // maps the provider addresses which can be used for dealing with offers
    mapping(address => bool) public isWhitelistedProvider;

    event TotalCapacitySet(address indexed provider, uint64 capacity);
    event BillingPlanSet(address indexed provider, address token, uint64 period, uint128 price);
    event MessageEmitted(address indexed provider, bytes32[] message);

    event NewAgreement(
        bytes32[] dataReference,
        address indexed agreementCreator,
        address indexed provider,
        uint64 size,
        uint64 billingPeriod,
        uint128 billingPrice,
        address token,
        uint256 availableFunds
    );
    event AgreementFundsDeposited(bytes32 indexed agreementReference, uint256 amount, address indexed token);
    event AgreementFundsWithdrawn(bytes32 indexed agreementReference, uint256 amount, address indexed token);
    event AgreementFundsPayout(bytes32 indexed agreementReference, uint256 amount, address indexed token);
    event AgreementStopped(bytes32 indexed agreementReference);

    function initialize() public initializer {
        __Ownable_init();
        __Pausable_init();
    }

    /**
    @notice whitelist a token or remove the token from whitelist
    @param token the token from whom you want to set the whitelisted
    @param isWhiteListed whether you want to whitelist the token or put it from the whitelist.
    */
    function setWhitelistedTokens(address token, bool isWhiteListed) public onlyOwner {
        isWhitelistedToken[token] = isWhiteListed;
    }

    /**
    @notice whitelist a provider or remove the provider from whitelist
    @param providerAddress the providerAddress from whom you want to set the whitelisted
    @param isWhiteListed whether you want to whitelist the provider or put it from the whitelist.
    */
    function setWhitelistedProvider(address providerAddress, bool isWhiteListed) public onlyOwner {
        isWhitelistedProvider[providerAddress] = isWhiteListed;
    }

    /**
    >> FOR PROVIDER
    @notice set the totalCapacity and billingPlans of a Offer.
    @dev
    - Use this function when initiating an Offer or when the users wants to change more than one parameter at once.
    - make sure that any period * prices does not cause an overflow, as this can never be accepted (REF_MAX_PRICE) and hence is pointless
    - only whitelisted tokens are allowed to make an offer for
    - if there are two tokens, and two billingPrice/periods pairs per token, then boundaries[0] == 1.
      This makes the first two billingPeriod/prices pairs to apply to the first token ([tokens[0]]) and the second pairs to the second token.
    - make sure that the length of billingPeriods and billingPrices is of equal length. If billingPeriods is longer than prices => array index out of bounds error. If prices longer than period => the prices in higher indeces won't be considered
    @param capacity the amount of MB offered. If already active before and set to 0, existing contracts can't be prolonged / re-started, no new contracts can be started.
    @param billingPeriods the offered periods. Length must be equal to the length of billingPrices. The first index of the multi dem array corresponds with the address in tokens at the same index
    @param billingPrices the prices for the offered periods. Each entry at index corresponds to the same index at periods. The first index of the multi dem array corresponds with the address in tokens at the same index
    @param tokens the tokens for which an offer is made. By convention, address(0) is the native currency.
    @param message the Provider may include a message (e.g. his nodeID).  Message should be structured such that the first two bits specify the message type, followed with the message). 0x01 == nodeID
    */
    function setOffer(
        uint64 capacity,
        uint64[][] memory billingPeriods,
        uint128[][] memory billingPrices,
        address[] memory tokens,
        bytes32[] memory message
    ) public whenNotPaused whitelistedProvider(msg.sender) {
        Offer storage offer = offerRegistry[msg.sender];
        setTotalCapacity(capacity);
        _setBillingPlansWithMultipleTokens(offer, billingPeriods, billingPrices, tokens);
        if (message.length > 0) {
            _emitMessage(message);
        }
    }

    /**
    >> FOR PROVIDER
    @notice sets total capacity of Offer.
    @param capacity the new capacity
    */
    function setTotalCapacity(uint64 capacity) public whenNotPaused whitelistedProvider(msg.sender) {
        require(capacity != 0, "StorageManager: Capacity has to be greater then zero");
        Offer storage offer = offerRegistry[msg.sender];
        offer.totalCapacity = capacity;
        emit TotalCapacitySet(msg.sender, capacity);
    }

    /**
    >> FOR PROVIDER
    @notice stops the Offer. It sets the totalCapacity to 0 which indicates terminated Offer.
    @dev no new Agreement can be created and no existing Agreement can be prolonged. All existing Agreement are still valid for the amount of periods still deposited.
    */
    function terminateOffer() public whitelistedProvider(msg.sender) {
        Offer storage offer = offerRegistry[msg.sender];
        require(offer.totalCapacity != 0, "StorageManager: Offer for this Provider doesn't exist");
        offer.totalCapacity = 0;
        emit TotalCapacitySet(msg.sender, 0);
    }

    /**
    >> FOR PROVIDER
    @notice set the billing plans for an Offer.
    @dev
    - setting the price to 0 means that a particular period is not offered, which can be used to remove a period from the offer.
    - make sure that any period * prices does not cause an overflow, as this can never be accepted and hence is pointless.
    - the length of tokens array must always be one shorter than the length of the boundaries array (otherwise you get an array index out of bounds error)
    - make sure that the length of billingPeriods and billingPrices is of equal length. If billingPeriods is longer than prices => array index out of bounds error. If prices longer than period => the prices in higher indeces won't be considered
    @param billingPeriods the offered periods. Length must be equal to billingPrices. The first index of the multi dem array corresponds with the address in tokens at the same index
    @param billingPrices the prices for the offered periods. Each entry at index corresponds to the same index at periods. 0 means that the particular period is not offered. The first index of the multi dem array corresponds with the address in tokens at the same index
    */
    function setBillingPlans(
        uint64[][] memory billingPeriods,
        uint128[][] memory billingPrices,
        address[] memory tokens
    ) public whenNotPaused whitelistedProvider(msg.sender) {
        Offer storage offer = offerRegistry[msg.sender];
        require(offer.totalCapacity != 0, "StorageManager: Offer for this Provider doesn't exist");
        _setBillingPlansWithMultipleTokens(offer, billingPeriods, billingPrices, tokens);
    }

    /**
    >> FOR PROVIDER
    @param message the Provider may send a message (e.g. his nodeID). Message should be structured such that the first two bits specify the message type, followed with the message). 0x01 == nodeID
    */
    function emitMessage(bytes32[] memory message) public {
        _emitMessage(message);
    }

    /**
    >> FOR CONSUMER
    @notice new Agreement for given Offer
    @dev
     - The to-be-pinned data reference's size in MB (rounded up) must be equal in size to param size.
     - Provider can reject to pin data reference when it exceeds specified size.
     - The ownership of Agreement is enforced with agreementReference structure which is calculated as: hash(msg.sender, dataReference)
     - if the token is not the native currency, then the contract must be first be given allowance to transfer tokens in it's posession.
     Contains execution of the transferFrom on external token contract before all the stage changes are performed.
     As a result if a token will perform a callback to the StorageManager,
     it may lead to a reentrancy attack. Hence additional attention should be paid while reviewing this method of a token before whitelisting.
    @param dataReference the reference to an Data Source, can be several things.
    @param provider the provider from which is proposed to take a Offer.
    @param size the size of the to-be-pinned file in MB (rounded up).
    @param billingPeriod the chosen period for billing.
    @param token the token in which you want to make the agreement. By convention: address(0) is the native currency
    @param amount if token is set, this is the amount of tokens that is transfered
    @param dataReferencesOfAgreementToPayOut the data references of agreements which must be payed out. Pass this when there is no capacity. Order should equal order of creatorsOfAgreementToPayOut and tokensOfAgreementToPayOut
    @param creatorsOfAgreementToPayOut the creators of agreements which must be payed out. Pass this when there is no capacity. The order should match the order of dataReferenceOfAgreementToPayOut and tokensOfAgreementToPayOut
    @param tokenOfAgreementsToPayOut the token address of agreements which must be payed out. Pass this when there is no capacity.
    */
    function newAgreement(
        bytes32[] memory dataReference,
        address provider,
        uint64 size,
        uint64 billingPeriod,
        address token,
        uint256 amount,
        bytes32[][] memory dataReferencesOfAgreementToPayOut,
        address[] memory creatorsOfAgreementToPayOut,
        address tokenOfAgreementsToPayOut
    ) public payable whenNotPaused {
        // Can not use modifier for this check as getting error that stack to deep
        require(isWhitelistedProvider[provider], "StorageManager: provider is not whitelisted");
        Offer storage offer = offerRegistry[provider];
        require(billingPeriod != 0, "StorageManager: Billing period of 0 not allowed");
        require(size > 0, "StorageManager: Size has to be bigger then 0");
        require(offer.totalCapacity != 0, "StorageManager: Offer for this Provider doesn't exist");
        require(isWhitelistedToken[token], "StorageManager: not possible to interact witht this token");
        // Allow to enforce payout funds and close of agreements that are already expired,
        // which should free needed capacity, if the capacity is becoming depleted.
        if (dataReferencesOfAgreementToPayOut.length > 0) {
            _payoutFunds(
                dataReferencesOfAgreementToPayOut,
                creatorsOfAgreementToPayOut,
                tokenOfAgreementsToPayOut,
                payable(provider)
            );
        }
        // the agreementReference consists of the hash of the dataReference, msg.sender and the tokenAdddress, to allow:
        // - multiple people to register an agreement for the same file
        // - one person to register multiple agreements for the same file, but with different tokens
        // - link the token to the agreement, such that we do the accounting properly
        bytes32 agreementReference = getAgreementReference(dataReference, msg.sender, token);
        // If the current agreement is still running (but for example already expired, eq. ran out of the funds in past)
        // we need to payout all the funds. AgreementStopped can be emitted as part of this call if no
        if (offer.agreementRegistry[agreementReference].lastPayoutDate != 0) {
            bytes32[][] memory dataReferenceOfAgreementToPayout = new bytes32[][](1);
            address[] memory creators = new address[](1);
            dataReferenceOfAgreementToPayout[0] = dataReference;
            creators[0] = msg.sender;
            _payoutFunds(dataReferenceOfAgreementToPayout, creators, token, payable(provider));
        }
        uint128 billingPrice = offer.billingPlansForToken[token][billingPeriod];
        require(billingPrice != 0, "StorageManager: Billing price doesn't exist for Offer");
        // can only define agreement here, because otherwise StakeTooDeep error
        Agreement storage agreement = offer.agreementRegistry[agreementReference];
        // Adding to previous availableFunds as the agreement could have been expired
        // and Consumer is reactivating it, so in order not to loose any previous funds.
        if (_isNativeToken(token)) {
            amount = msg.value;
        }

        agreement.availableFunds = agreement.availableFunds.add(amount);
        require(
            agreement.availableFunds >= size.mul(billingPrice),
            "StorageManager: Funds deposited has to be for at least one billing period"
        );
        agreement.size = size;
        agreement.billingPrice = billingPrice;
        agreement.billingPeriod = billingPeriod;

        // Set to current time as no payout was made yet and this information is
        // used to track spent funds.
        agreement.lastPayoutDate = uint128(_time());
        offer = offerRegistry[provider];
        offer.utilizedCapacity = uint64(offer.utilizedCapacity.add(size));
        require(offer.utilizedCapacity <= offer.totalCapacity, "StorageManager: Insufficient Offer's capacity");

        if (!_isNativeToken(token)) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
        emit NewAgreement(
            dataReference,
            msg.sender,
            provider,
            size,
            billingPeriod,
            billingPrice,
            token,
            agreement.availableFunds
        );
    }

    /**
    >> FOR CONSUMER
    @notice deposits new funds to the Agreement.
    @dev
        - depositing funds to Agreement that is linked to terminated Offer is not possible
        - depositing funds to Agreement that already is expired (eq. ran out of funds at some point) is not possible.
          Call NewAgreement instead. The data needs to be re-provided though.
        - if the token is not the native currency, then the contract must be first be given allowance to transfer tokens in it's posession.
    @param dataReference data reference where should be deposited funds.
    @param provider the address of the provider of the Offer.
    */
    function depositFunds(
        address token,
        uint256 amount,
        bytes32[] memory dataReference,
        address provider
    ) public payable whenNotPaused whitelistedProvider(provider) {
        bytes32 agreementReference = getAgreementReference(dataReference, msg.sender, token);
        require(isWhitelistedToken[token], "StorageManager: Token is not whitelisted");
        Offer storage offer = offerRegistry[provider];
        require(offer.totalCapacity != 0, "StorageManager: Offer for this Provider doesn't exist");
        Agreement storage agreement = offer.agreementRegistry[agreementReference];
        require(agreement.size != 0, "StorageManager: Agreement for this Offer doesn't exist");
        require(agreement.lastPayoutDate != 0, "StorageManager: Agreement not active");
        require(
            offer.billingPlansForToken[token][agreement.billingPeriod] == agreement.billingPrice,
            "StorageManager: Price not available anymore"
        );
        require(
            agreement.availableFunds.sub(_calculateSpentFunds(agreement)) >= agreement.billingPrice.mul(agreement.size),
            "StorageManager: Agreement already ran out of funds"
        );
        bool isNativeToken = _isNativeToken(token);
        if (isNativeToken) {
            amount = msg.value;
        }
        agreement.availableFunds = agreement.availableFunds.add(amount);
        if (!isNativeToken) {
            // contract must be allowed to transfer
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
        emit AgreementFundsDeposited(agreementReference, amount, token);
    }

    /**
    >> FOR CONSUMER
    @notice withdraw funds from Agreement.
    @dev
        - if amount is zero then all withdrawable funds are transferred (eq. all available funds minus funds for still non-payed out periods and current period)
        - if Agreement is terminated Consumer can withdraw all remaining funds
        - if the token is not the native currency, then the contract must be first be given allowance to transfer tokens in it's posession.
    @param dataReference the data reference of agreement to be funds withdrawn from
    @param provider the address of the provider of the Offer.
    @param tokens the tokens in which to withdraw. By convention, address(0) is the native currency.
    @param amounts the value you want to withdraw for each token
    */
    function withdrawFunds(
        bytes32[] memory dataReference,
        address provider,
        address[] memory tokens,
        uint256[] memory amounts
    ) public {
        Offer storage offer = offerRegistry[provider];
        for (uint256 i; i < tokens.length; i++) {
            uint256 amount = amounts[i];
            address token = tokens[i];
            bytes32 agreementReference = getAgreementReference(dataReference, msg.sender, token);
            Agreement storage agreement = offer.agreementRegistry[agreementReference];
            require(agreement.size != 0, "StorageManager: Agreement for this Offer doesn't exist");
            uint256 maxWithdrawableFunds;
            if (agreement.lastPayoutDate == 0) {
                // Agreement is inactive, consumer can withdraw all funds
                maxWithdrawableFunds = agreement.availableFunds;
            } else {
                // Consumer can withdraw all funds except for those already used for past storage hosting
                // AND for current period
                maxWithdrawableFunds = agreement.availableFunds.sub(_calculateSpentFunds(agreement)).sub(
                    (agreement.billingPrice * agreement.size)
                );
            }

            if (amount == 0) {
                amount = maxWithdrawableFunds;
            }
            require(amount <= maxWithdrawableFunds, "StorageManager: Amount is too big");
            agreement.availableFunds = agreement.availableFunds.sub(amount);
            require(amount > 0, "StorageManager: Nothing to withdraw");

            if (_isNativeToken(token)) {
                (bool success, ) = msg.sender.call{value: amount}("");
                require(success, "Transfer failed.");
            } else {
                IERC20(token).safeTransfer(msg.sender, amount);
            }
            emit AgreementFundsWithdrawn(agreementReference, amount, token);
        }
    }

    /**
    >> FOR PROVIDER
    @notice payout already earned funds of one or more Agreement
    @dev
    - Provider must call an expired agreement themselves as soon as the agreement is expired, to add back the capacity to their Offer.
    - Payout can be triggered by other events as well. Like in newAgreement call with either existing agreement or when other
      Agreements are passed to the agreementsReferencesToBePayedOut array.
    @param dataReferencesOfAgreementToPayOut the data references of the agreement to pay
    @param creatorsOfAgreementToPayOut the creators that made the agreement to pay
    @param tokensOfAgreementsToPayOut the tokens of the agreement to pay out
    */

    function payoutFunds(
        bytes32[][] memory dataReferencesOfAgreementToPayOut,
        address[] memory creatorsOfAgreementToPayOut,
        address tokensOfAgreementsToPayOut,
        address payable provider
    ) public whitelistedProvider(provider) {
        _payoutFunds(
            dataReferencesOfAgreementToPayOut,
            creatorsOfAgreementToPayOut,
            tokensOfAgreementsToPayOut,
            provider
        );
    }

    /**
    @notice sets the billing plans for multiple tokens.
    @dev
    - the billingPeriods and billingPrices hold the period/price pair for all tokens.
    - the length of tokens array must always be one shorter than the length of the boundaries array (otherwise you get an array index out of bounds error)
    - make sure that the length of billingPeriods and billingPrices is of equal length. If billingPeriods is longer than prices => array index out of bounds error. If prices longer than period => the prices in higher indeces won't be considered
    @param offer the offer for which the billingPlan is set
    @param billingPeriods the offered periods. Length must be equal to the length of billingPrices. The first index of the multi dem array corresponds with the address in tokens at the same index
    @param billingPrices the prices for the offered periods. Each entry at index corresponds to the same index at periods. 0 means that the particular period is not offered. The first index of the multi dem array corresponds with the address in tokens at the same index
    @param tokens the tokens for which an offer is made. By convention, address(0) is the native currency.
    */
    function _setBillingPlansWithMultipleTokens(
        Offer storage offer,
        uint64[][] memory billingPeriods,
        uint128[][] memory billingPrices,
        address[] memory tokens
    ) internal {
        // iterate once for each token
        for (uint256 i; i < tokens.length; i++) {
            // for each token, list all period/price pairs
            for (uint256 j; j < billingPeriods[i].length; j++) {
                _setBillingPlanForToken(offer, tokens[i], billingPeriods[i][j], billingPrices[i][j]);
            }
        }
    }

    function hasUtilizedCapacity(address storer) public view returns (bool) {
        return (offerRegistry[storer].utilizedCapacity != 0);
    }

    // Only one token can be used to pay out
    function _payoutFunds(
        bytes32[][] memory dataReferenceOfAgreementToPayOut,
        address[] memory creatorsOfAgreementToPayOut,
        address tokenOfAgreementsToPayOut,
        address payable provider
    ) internal {
        Offer storage offer = offerRegistry[provider];
        uint256 toTransfer;

        for (uint8 i = 0; i < dataReferenceOfAgreementToPayOut.length; i++) {
            bytes32 agreementReference =
                getAgreementReference(
                    dataReferenceOfAgreementToPayOut[i],
                    creatorsOfAgreementToPayOut[i],
                    tokenOfAgreementsToPayOut
                );
            Agreement storage agreement = offer.agreementRegistry[agreementReference];
            require(agreement.size != 0, "StorageManager: Agreement for this Offer doesn't exist");
            // Was already payed out and terminated
            require(agreement.lastPayoutDate != 0, "StorageManager: Agreement is inactive");

            uint256 spentFunds = _calculateSpentFunds(agreement);
            if (spentFunds > 0) {
                agreement.availableFunds = agreement.availableFunds.sub(spentFunds);
                toTransfer = toTransfer.add(spentFunds);

                // Agreement ran out of funds ==> Agreement is expiring
                if (agreement.availableFunds < agreement.billingPrice.mul(agreement.size)) {
                    // Agreement becomes inactive
                    agreement.lastPayoutDate = 0;

                    // Add back capacity
                    offer.utilizedCapacity = uint64(offer.utilizedCapacity.sub(agreement.size));
                    emit AgreementStopped(agreementReference);
                } else {
                    // Provider called this during active agreement which has still funds to run
                    agreement.lastPayoutDate = uint128(_time());
                }

                emit AgreementFundsPayout(agreementReference, spentFunds, tokenOfAgreementsToPayOut);
            }
        }

        if (toTransfer > 0) {
            if (_isNativeToken(tokenOfAgreementsToPayOut)) {
                (bool success, ) = provider.call{value: toTransfer}("");
                require(success, "StorageManager: Transfer failed.");
            } else {
                IERC20(tokenOfAgreementsToPayOut).safeTransfer(provider, toTransfer);
            }
        }
    }

    /**
     * @dev Called by a pauser to pause, triggers stopped state.
     */
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @dev Called by a pauser to unpause, returns to normal state.
     */
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    /**
    @notice get the agreementReference.
    the agreementReference consists of the hash of the dataReference, msg.sender and the tokenAdddress, to allow:
     - multiple people to register an agreement for the same file
     - one person to register multiple agreements for the same file, but with different tokens
     - link the token to the agreement, such that we do the accounting properly
    @param dataReference the dataReference of the agreement
    @param creator the creator of the agreement
    @param token the token, which is used as a means of payment for the agreement.
    */
    function getAgreementReference(
        bytes32[] memory dataReference,
        address creator,
        address token
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(creator, dataReference, token));
    }

    function _calculateSpentFunds(Agreement memory agreement) internal view returns (uint256) {
        // TODO: Can be most probably smaller then uint256
        uint256 totalPeriodPrice = agreement.size.mul(agreement.billingPrice);
        uint256 periodsSinceLastPayout = _time().sub(agreement.lastPayoutDate).div(agreement.billingPeriod);
        uint256 spentFunds = periodsSinceLastPayout.mul(totalPeriodPrice);

        // Round the funds based on the available funds
        if (spentFunds > agreement.availableFunds) {
            spentFunds = agreement.availableFunds.div(totalPeriodPrice).mul(totalPeriodPrice);
        }

        return spentFunds;
    }

    /*
    @dev Only non-zero prices periods are considered to be active. To remove a period, set it's price to 0
    */
    function _setBillingPlanForToken(
        Offer storage offer,
        address token,
        uint64 period,
        uint128 price
    ) internal {
        require(period <= MAX_BILLING_PERIOD, "StorageManager: Billing period exceed max. length");
        require(isWhitelistedToken[token], "StorageManager: Token is not whitelisted");
        offer.billingPlansForToken[token][period] = price;
        emit BillingPlanSet(msg.sender, token, period, price);
    }

    function _emitMessage(bytes32[] memory message) internal {
        emit MessageEmitted(msg.sender, message);
    }

    /**
    @dev Helper function for testing timing overloaded in testing contract
    */
    function _time() internal view virtual returns (uint256) {
        return now;
    }

    /**
    @notice if use a native token
     */
    function _isNativeToken(address token) internal pure returns (bool) {
        return token == address(0);
    }

    modifier whitelistedProvider(address provider) {
        require(isWhitelistedProvider[provider], "StorageManager: provider is not whitelisted");
        _;
    }
}
