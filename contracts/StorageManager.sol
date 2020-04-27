pragma solidity 0.6.2;

import "./vendor/SafeMath.sol";

/// @title StorageManager
/// @author Rinke Hendriksen <rinke@iovlabs.org>
/// @author Adam Uhlir <adam@iovlabs.org>
/// @notice Providers can offer their storage space and list their price and Consumers can take these offers
contract StorageManager {

    using SafeMath for uint256;
    using SafeMath for uint128;
    using SafeMath for uint64;
    uint64 constant private MAX_UINT64 = 18446744073709551615;

    /*
    Offer represents:
     - availableCapacity: the amount of bytes currently offered. When the capacity is zero, already started Agreement can't be prolonged or re-started ==> it is terminated
     - billingPlans: maps a billing period to a billing price. When a price is 0, the period is not offered.
     - agreementRegistry: the proposed and accepted Agreement
    */
    struct Offer {
        uint128 availableCapacity;
        mapping(uint64 => uint64) billingPlans;
        mapping(bytes32 => Agreement) agreementRegistry; // link to agreement that are accepted under this offer
    }

    /*
    Agreement represents:
     - billingPrice: price per byte that is collected per each period.
     - billingPeriod: period how often billing happens.
     - size: allocated size for the Agreement (in bytes, rounded up)
     - availableFunds: funds available for the billing of the Agreement.
     - lastPayoutDate: When was the last time Provider was payed out. Zero either means non-existing or terminated Agreement.
    */
    struct Agreement {
        uint64 billingPrice;
        uint64 billingPeriod;
        uint256 availableFunds;
        uint128 size;
        uint128 lastPayoutDate;
    }

    // offerRegistry stores the open or closed Offer for provider.
    mapping(address => Offer) public offerRegistry;

    event AvailableCapacitySet(address indexed provider, uint128 capacity);
    event BillingPlanSet(address indexed provider, uint64 period, uint64 price);
    event MessageEmitted(address indexed provider, bytes32[] message);

    event NewAgreement(
        bytes32 agreementReference,
        bytes32[] dataReference,
        address indexed agreementAuthor, // TODO: [Q] Do we need information about who created the Agreement?
        address indexed provider,
        uint128 size,
        uint64 billingPeriod,
        uint64 billingPrice,
        uint256 availableFunds
    );
    event AgreementFundsDeposited(bytes32 indexed agreementReference, uint256 amount);
    event AgreementFundsWithdrawn(bytes32 indexed agreementReference, uint256 amount);
    event AgreementFundsPayout(bytes32 indexed agreementReference, uint256 amount);
    event AgreementStopped(bytes32 indexed agreementReference);

    /**
    >> FOR PROVIDER
    @notice set the availableCapacity and billingPlans of a Offer.
    @dev
    - Use this function when initiating an Offer or when the users wants to change more than one parameter at once.
    - Exercise caution with assigning additional capacity when capacity is already taken.
        It may happen that when a lot of capacity is available and we release already-taken capacity, capacity overflows.
        We explicitly allow this overflow to happen on the smart-contract level,
        because the worst thing that can happen is that the provider now has less storage available than planned (in which case he can top it up himself).
        However, take care of this in the client. REF_CAPACITY
    - make sure that any period * prices does not cause an overflow, as this can never be accepted (REF_MAX_PRICE) and hence is pointless
    @param capacity the amount of bytes offered.
    If already active before and set to 0, existing contracts can't be prolonged / re-started, no new contracts can be started.
    @param billingPeriods the offered periods. Length must be equal to the lenght of billingPrices.
    @param billingPrices the prices for the offered periods. Each entry at index corresponds to the same index at periods. When a price is 0, the matching period is not offered.
    @param message the Provider may include a message (e.g. his nodeID).  Message should be structured such that the first two bits specify the message type, followed with the message). 0x01 == nodeID
    */
    function setOffer(uint128 capacity,
        uint64[] memory billingPeriods,
        uint64[] memory billingPrices,
        bytes32[] memory message
    ) public {
        Offer storage offer = offerRegistry[msg.sender];
        _setAvailableCapacity(offer, capacity);
        require(billingPeriods.length > 0, "StorageManager: Offer needs some billing plans");
        require(billingPeriods.length == billingPrices.length, "StorageManager: Billing plans array length has to equal to billing prices");
        for (uint8 i = 0; i < billingPeriods.length; i++) {
            _setBillingPlan(offer, billingPeriods[i], billingPrices[i]);
        }
        if (message.length > 0) {
            _emitMessage(message);
        }
    }

    /**
    >> FOR PROVIDER
    @notice increases the capacity of a Offer.
    @dev exercise caution with assigning additional capacity when capacity is already taken.
    It may happen that when a lot of capacity is available and we release already-taken capacity, capacity overflows.
    We explicitly allow this overflow to happen on the smart-contract level,
    because the worst thing that can happen is that the provider now has less storage available than planned (in which case he can top it up himself).
    However, take care of this in the client. REF_CAPACITY
    @param increase the increase in capacity (in bytes).
    */
    function increaseAvailableCapacity(uint128 increase) public {
        Offer storage offer = offerRegistry[msg.sender];
        _setAvailableCapacity(offer, uint128(offer.availableCapacity.add(increase)));
    }

    /**
    >> FOR PROVIDER
    @notice decreases the capacity of a Offer.
    @dev use function stopStorage if you want to set the capacity to 0 (and thereby stop the Offer)
    @param decrease the decrease in capacity (in bytes).
    */
    function decreaseAvailableCapacity(uint128 decrease) public {
        Offer storage offer = offerRegistry[msg.sender];
        _setAvailableCapacity(offer, uint128(offer.availableCapacity.sub(decrease)));
    }

    /**
   @notice stops the Offer.
   @dev when capacity is set to 0, no new Agreement can be created and no existing Agreement can be prolonged. All existing Agreement are still valid for the amount of periods still deposited.
   */
    function terminateOffer() public {
        Offer storage offer = offerRegistry[msg.sender];
        _setAvailableCapacity(offer, 0);
    }

    /**
    >> FOR PROVIDER
    @notice set the billing plans for an Offer.
    @dev
    - setting the price to 0 means that a particular period is not offered, which can be used to remove a period from the offer.
    - make sure that any period * prices does not cause an overflow, as this can never be accepted (REF_MAX_PRICE) and hence is pointless.
    @param billingPeriods the offered periods. Length must be equal to billingPrices.
    @param billingPrices the prices for the offered periods. Each entry at index corresponds to the same index at periods. 0 means that the particular period is not offered.
    */
    function setBillingPlans(uint64[] memory billingPeriods, uint64[] memory billingPrices) public {
        Offer storage offer = offerRegistry[msg.sender];
        for (uint8 i = 0; i < billingPeriods.length; i++) {
            _setBillingPlan(offer, billingPeriods[i], billingPrices[i]);
        }
    }

    /**
    @param message the Provider may send a message (e.g. his nodeID). Message should be structured such that the first two bits specify the message type, followed with the message). 0x01 == nodeID
    */
    function emitMessage(bytes32[]memory message) public {
        _emitMessage(message);
    }

    /**
    >> FOR CONSUMER
    @notice new Agreement for given Offer
    @dev
     - The to-be-pinned data reference's size in bytes (rounded up) must be equal in size to param size.
     - Provider can reject to pin data reference when it exceeds specified size.
     - The ownership of Agreement is enforced with agreementReference structure which is calculated as: hash(msg.sender, dataReference)
    @param dataReference the reference to an Data Source, can be several things.
    @param provider the provider from which is proposed to take a Offer.
    @param size the size of the to-be-pinned file in bytes (rounded up).
    @param billingPeriod the chosen period for billing.
    @param agreementsReferencesToBePayedOut Agreements that are supposed to be terminated and should be payed-out and capacity freed up.
    */
    function newAgreement(bytes32[] memory dataReference, address provider, uint128 size, uint64 billingPeriod, bytes32[] memory agreementsReferencesToBePayedOut) public payable {
        require(billingPeriod != 0, "StorageManager: billing period of 0 not allowed");
        require(size > 0, "StorageManager: size has to be bigger then 0");

        Offer storage offer = offerRegistry[provider];
        require(offer.availableCapacity != 0, "StorageManager: Offer for this provider doesn't exist");

        bytes32 agreementReference = getAgreementReference(dataReference, msg.sender);
        Agreement storage agreement = offer.agreementRegistry[agreementReference];
        require(agreement.lastPayoutDate == 0, "StorageManager: Agreement already active");

        uint64 billingPrice = offer.billingPlans[billingPeriod];
        require(billingPrice != 0, "StorageManager: billing price doesn't exist for Offer");

        // Adding to previous availableFunds as the agreement could have been expired
        // and Consumer is reactivating it, so in order not to loose any previous funds.
        agreement.availableFunds = agreement.availableFunds.add(msg.value);
        require(agreement.availableFunds >= size * billingPrice, "StorageManager: funds deposited has to be for at least one billing period");

        agreement.size = size;
        agreement.billingPrice = billingPrice;
        agreement.billingPeriod = billingPeriod;
        agreement.lastPayoutDate = uint128(_time());

        // Allow to enforce payout funds and close of agreements that are already expired,
        // which should free needed capacity, if the capacity is becoming depleted.
        if(agreementsReferencesToBePayedOut.length > 0) {
            _payoutFunds(agreementsReferencesToBePayedOut, payable(provider));
        }

        offer = offerRegistry[provider];
        // Will revert when the size should be smaller then zero
        offer.availableCapacity = uint128(offer.availableCapacity.sub(size, "StorageManager: Insufficient capacity"));

        emit NewAgreement(
            agreementReference,
            dataReference,
            msg.sender,
            provider,
            size,
            billingPeriod,
            billingPrice,
            agreement.availableFunds
        );
    }

    /**
    >> FOR CONSUMER
    @notice deposits new funds to the Agreement.
    @dev
        - depositing funds to Agreement that is linked to terminated Offer is not possible
    @param dataReference data reference where should be deposited funds.
    @param provider the address of the provider of the Offer.
    */
    function depositFunds(bytes32[] memory dataReference, address provider) public payable {
        bytes32 agreementReference = getAgreementReference(dataReference, msg.sender);
        Offer storage offer = offerRegistry[provider];
        require(offer.availableCapacity != 0, "StorageManager: Offer for this Provider doesn't exist");

        Agreement storage agreement = offer.agreementRegistry[agreementReference];
        require(agreement.size != 0, "StorageManager: Agreement for this Offer doesn't exist");
        require(agreement.lastPayoutDate != 0, "StorageManager: Agreement not active");

        // TODO: [Q] Should we disallow depositing funds to Agreement whose chosen price does not exists anymore? What other options user has then?
        require(offer.billingPlans[agreement.billingPeriod] != 0, "StorageManager: price not available anymore");

        agreement.availableFunds = agreement.availableFunds.add(msg.value);
        emit AgreementFundsDeposited(agreementReference, msg.value);
    }

    /**
    >> FOR CONSUMER
    @notice withdraw funds from Agreement.
    @dev
        - if amount is zero then all withdrawable funds are transferred (eq. all available funds minus funds for still non-payed out periods and current period)
        - if Agreement is terminated Consumer can withdraw all remaining funds
    @param dataReference the data reference of agreement to be funds withdrawn from
    @param provider the address of the provider of the Offer.
    */
    function withdrawFunds(bytes32[] memory dataReference, address provider, uint256 amount) public payable {
        Offer storage offer = offerRegistry[provider];
        require(offer.availableCapacity != 0, "StorageManager: Offer for this Provider doesn't exist");

        bytes32 agreementReference = getAgreementReference(dataReference, msg.sender);
        Agreement storage agreement = offer.agreementRegistry[agreementReference];
        require(agreement.size != 0, "StorageManager: Agreement for this Offer doesn't exist");

        uint256 maxWithdrawableFunds;
        if (agreement.lastPayoutDate == 0) {
            // Agreement is inactive, consumer can withdraw all funds
            maxWithdrawableFunds = agreement.availableFunds;
        } else {
            // Consumer can withdraw all funds except for those already used for past storage hosting
            // AND for current period
            maxWithdrawableFunds = agreement.availableFunds - _calculateSpentFunds(agreement) - (agreement.billingPrice * agreement.size);
        }

        if (amount == 0) {
            amount = maxWithdrawableFunds;
        }

        require(amount <= maxWithdrawableFunds, "StorageManager: Amount is too big");
        agreement.availableFunds = agreement.availableFunds.sub(amount);
        msg.sender.transfer(amount);
        emit AgreementFundsWithdrawn(agreementReference, amount);
    }

    /**
    >> FOR PROVIDER
    @notice payout already earned funds of one or more Agreement
    @dev 
    - Provider must call an expired agreement themselves as soon as the agreement is expired, to add back the capacity to their Offer.
    @param agreementReferences reference to one or more Agreement
    */
    function payoutFunds(bytes32[] memory agreementReferences) public {
        _payoutFunds(agreementReferences, msg.sender);
    }

    function _payoutFunds(bytes32[] memory agreementReferences, address payable provider) internal {
        Offer storage offer = offerRegistry[provider];
        require(offer.availableCapacity != 0, "StorageManager: Offer for this Provider doesn't exist");
        uint256 toTransfer;
        for (uint8 i = 0; i < agreementReferences.length; i++) {
        Agreement storage agreement = offer.agreementRegistry[agreementReferences[i]];
            require(agreement.size != 0, "StorageManager: Agreement for this Offer doesn't exist");

            // TODO: [Q] Should we disallow to payout from inactive agreement? Can it cause some deadlock?
            require(agreement.lastPayoutDate != 0, "StorageManager: Agreement is inactive");

            uint256 spentFunds = _calculateSpentFunds(agreement);
            agreement.availableFunds = agreement.availableFunds.sub(spentFunds);
            toTransfer = toTransfer.add(spentFunds);

            // Agreement ran out of funds ==> Agreement is expiring
            if (agreement.availableFunds < agreement.billingPrice * agreement.size) {
                // Agreement becomes inactive
                agreement.lastPayoutDate = 0;

                // TODO: [Q] Should we automatically return any remaining agreement.availableFunds?
                // Check if Offer is still active
                if (offer.availableCapacity != 0) {
                    //ALLOW_OVERFLOW reasoning: see: REF_CAPACITY
                    // add back capacity
                    offer.availableCapacity = offer.availableCapacity + agreement.size;
                }

                emit AgreementStopped(agreementReferences[i]);
            } else {// Provider called this during active agreement which has still funds to run
                agreement.lastPayoutDate = uint128(_time());
            }

            emit AgreementFundsPayout(agreementReferences[i], spentFunds);
        }
        provider.transfer(toTransfer);
    }

    function getAgreementReference(bytes32[] memory dataReference, address author) public view returns (bytes32) {
        return keccak256(abi.encodePacked(author, dataReference));
    }

    function _calculateSpentFunds(Agreement memory agreement) internal view returns (uint256) {
        // TODO: Can be most probably smaller then uint256
        uint256 totalPeriodPrice = agreement.size * agreement.billingPrice;
        uint256 periodsSinceLastPayout = (_time() - agreement.lastPayoutDate) / agreement.billingPeriod;
        uint256 spentFunds = periodsSinceLastPayout * totalPeriodPrice;

        // Round the funds based on the available funds
        if (spentFunds > agreement.availableFunds) {
            spentFunds = (agreement.availableFunds / totalPeriodPrice) * totalPeriodPrice;
        }

        return spentFunds;
    }

    function _setAvailableCapacity(Offer storage offer, uint128 capacity) internal {
        offer.availableCapacity = capacity;
        emit AvailableCapacitySet(msg.sender, capacity);
    }

    /*
    @dev Only non-zero prices periods are considered to be active. To remove a period, set it's price to 0
    */
    function _setBillingPlan(Offer storage offer, uint64 period, uint64 price) internal {
        offer.billingPlans[period] = price;
        emit BillingPlanSet(msg.sender, period, price);
    }

    function _emitMessage(bytes32[] memory message) internal {
        emit MessageEmitted(msg.sender, message);
    }

    /**
    @dev Helper function for testing timing overloaded in testing contract
    */
    function _time() internal view virtual returns (uint) {
        return now;
    }
}
