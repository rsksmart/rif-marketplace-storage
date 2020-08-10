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
    uint64 constant private MAX_BILLING_PERIOD = 15552000; // 6 * 30 days ~~ 6 months

    /*
    Offer represents:
     - utilizedCapacity: how much is capacity is utilized in Offer.
     - totalCapacity: total amount of bytes offered.
     - billingPlans: maps a billing period to a billing price. When a price is 0, the period is not offered.
     - agreementRegistry: the proposed and accepted Agreement
    */
    struct Offer {
        uint128 utilizedCapacity;
        uint128 totalCapacity;
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

    event TotalCapacitySet(address indexed provider, uint128 capacity);
    event BillingPlanSet(address indexed provider, uint64 period, uint64 price);
    event PeerIdEmitted(address indexed provider, bytes32[] peerId);

    event NewAgreement(
        bytes32 agreementReference,
        bytes32[] dataReference,
        address indexed agreementCreator,
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
    @notice set the totalCapacity and billingPlans of a Offer.
    @dev
    - Use this function when initiating an Offer or when the users wants to change more than one parameter at once.
    - make sure that any period * prices does not cause an overflow, as this can never be accepted (REF_MAX_PRICE) and hence is pointless
    @param capacity the amount of bytes offered. If already active before and set to 0, existing contracts can't be prolonged / re-started, no new contracts can be started.
    @param billingPeriods the offered periods. Length must be equal to the lenght of billingPrices.
    @param billingPrices the prices for the offered periods. Each entry at index corresponds to the same index at periods. When a price is 0, the matching period is not offered.
    @param peerId that Provider's node uses for off-chain communication and for authentication of his messages.
    */
    function setOffer(uint128 capacity,
        uint64[] memory billingPeriods,
        uint64[] memory billingPrices,
        bytes32[] memory peerId
    ) public {
        Offer storage offer = offerRegistry[msg.sender];
        setTotalCapacity(capacity);
        require(billingPeriods.length > 0, "StorageManager: Offer needs some billing plans");
        require(billingPeriods.length == billingPrices.length, "StorageManager: Billing plans array length has to equal to billing prices");
        for (uint8 i = 0; i < billingPeriods.length; i++) {
            _setBillingPlan(offer, billingPeriods[i], billingPrices[i]);
        }
        emitPeerId(peerId);
    }

    /**
    >> FOR PROVIDER
    @notice sets total capacity of Offer.
    @param capacity the new capacity
    */
    function setTotalCapacity(uint128 capacity) public {
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
    function terminateOffer() public {
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
    - make sure that any period * prices does not cause an overflow, as this can never be accepted (REF_MAX_PRICE) and hence is pointless.
    @param billingPeriods the offered periods. Length must be equal to billingPrices.
    @param billingPrices the prices for the offered periods. Each entry at index corresponds to the same index at periods. 0 means that the particular period is not offered.
    */
    function setBillingPlans(uint64[] memory billingPeriods, uint64[] memory billingPrices) public {
        require(billingPeriods.length > 0, "StorageManager: Offer needs some billing plans");
        require(billingPeriods.length == billingPrices.length, "StorageManager: Billing plans array length has to equal to billing prices");
        Offer storage offer = offerRegistry[msg.sender];
        require(offer.totalCapacity != 0, "StorageManager: Offer for this Provider doesn't exist");
        for (uint8 i = 0; i < billingPeriods.length; i++) {
            _setBillingPlan(offer, billingPeriods[i], billingPrices[i]);
        }
    }

    /**
    >> FOR PROVIDER
    @param peerId that his node uses for off-chain communication and for authentication of his messages.
    */
    function emitPeerId(bytes32[]memory peerId) public {
        require(peerId.length > 0, "StorageManager: PeerId must be set");
        emit PeerIdEmitted(msg.sender, peerId);
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
        require(billingPeriod != 0, "StorageManager: Billing period of 0 not allowed");
        require(size > 0, "StorageManager: Size has to be bigger then 0");

        Offer storage offer = offerRegistry[provider];
        require(offer.totalCapacity != 0, "StorageManager: Offer for this Provider doesn't exist");
        bytes32 agreementReference = getAgreementReference(dataReference, msg.sender);
        Agreement storage agreement = offer.agreementRegistry[agreementReference];

        // If the current agreement is still running (but for example already expired, eq. ran out of the funds in past)
        // we need to payout all the funds. AgreementStopped can be emitted as part of this call if no
        if(agreement.lastPayoutDate != 0){
            bytes32[] memory array = new bytes32[](1);
            array[0] = agreementReference;
            _payoutFunds(array, payable(provider));
        }

        uint64 billingPrice = offer.billingPlans[billingPeriod];
        require(billingPrice != 0, "StorageManager: Billing price doesn't exist for Offer");

        // Adding to previous availableFunds as the agreement could have been expired
        // and Consumer is reactivating it, so in order not to loose any previous funds.
        agreement.availableFunds = agreement.availableFunds.add(msg.value);
        require(agreement.availableFunds >= size * billingPrice, "StorageManager: Funds deposited has to be for at least one billing period");

        agreement.size = size;
        agreement.billingPrice = billingPrice;
        agreement.billingPeriod = billingPeriod;

        // Set to current time as no payout was made yet and this information is
        // used to track spent funds.
        agreement.lastPayoutDate = uint128(_time());

        // Allow to enforce payout funds and close of agreements that are already expired,
        // which should free needed capacity, if the capacity is becoming depleted.
        if (agreementsReferencesToBePayedOut.length > 0) {
            _payoutFunds(agreementsReferencesToBePayedOut, payable(provider));
        }

        offer = offerRegistry[provider];
        offer.utilizedCapacity = uint128(offer.utilizedCapacity.add(size));
        require(offer.utilizedCapacity <= offer.totalCapacity, "StorageManager: Insufficient Offer's capacity");

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
        - depositing funds to Agreement that already is expired (eq. ran out of funds at some point) is not possible.
          Call NewAgreement instead. The data needs to be re-provided though.
    @param dataReference data reference where should be deposited funds.
    @param provider the address of the provider of the Offer.
    */
    function depositFunds(bytes32[] memory dataReference, address provider) public payable {
        bytes32 agreementReference = getAgreementReference(dataReference, msg.sender);
        Offer storage offer = offerRegistry[provider];
        require(offer.totalCapacity != 0, "StorageManager: Offer for this Provider doesn't exist");
        Agreement storage agreement = offer.agreementRegistry[agreementReference];
        require(agreement.size != 0, "StorageManager: Agreement for this Offer doesn't exist");
        require(agreement.lastPayoutDate != 0, "StorageManager: Agreement not active");
        require(offer.billingPlans[agreement.billingPeriod] == agreement.billingPrice, "StorageManager: Price not available anymore");
        require(agreement.availableFunds - _calculateSpentFunds(agreement) > agreement.billingPrice * agreement.size, "StorageManager: Agreement already ran out of funds");

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

        require(amount > 0, "StorageManager: Nothing to withdraw");
        (bool success,) = msg.sender.call.value(amount)("");
        require(success, "Transfer failed.");

        emit AgreementFundsWithdrawn(agreementReference, amount);
    }

    /**
    >> FOR PROVIDER
    @notice payout already earned funds of one or more Agreement
    @dev
    - Provider must call an expired agreement themselves as soon as the agreement is expired, to add back the capacity to their Offer.
    - Payout can be triggered by other events as well. Like in newAgreement call with either existing agreement or when other
      Agreements are passed to the agreementsReferencesToBePayedOut array.
    @param agreementReferences reference to one or more Agreement
    */
    function payoutFunds(bytes32[] memory agreementReferences) public {
        _payoutFunds(agreementReferences, msg.sender);
    }

    function _payoutFunds(bytes32[] memory agreementReferences, address payable provider) internal {
        Offer storage offer = offerRegistry[provider];
        uint256 toTransfer = 0;
        for (uint8 i = 0; i < agreementReferences.length; i++) {
            Agreement storage agreement = offer.agreementRegistry[agreementReferences[i]];
            require(agreement.size != 0, "StorageManager: Agreement for this Offer doesn't exist");
            // Was already payed out and terminated
            require(agreement.lastPayoutDate != 0, "StorageManager: Agreement is inactive");

            uint256 spentFunds = _calculateSpentFunds(agreement);
            if(spentFunds > 0){
                agreement.availableFunds = agreement.availableFunds.sub(spentFunds);
                toTransfer = toTransfer.add(spentFunds);

                // Agreement ran out of funds ==> Agreement is expiring
                if (agreement.availableFunds < agreement.billingPrice * agreement.size) {
                    // Agreement becomes inactive
                    agreement.lastPayoutDate = 0;

                    // Add back capacity
                    offer.utilizedCapacity = offer.utilizedCapacity - agreement.size;
                    emit AgreementStopped(agreementReferences[i]);
                } else {// Provider called this during active agreement which has still funds to run
                    agreement.lastPayoutDate = uint128(_time());
                }

                emit AgreementFundsPayout(agreementReferences[i], spentFunds);
            }
        }

        if(toTransfer > 0){
            (bool success,) = provider.call.value(toTransfer)("");
            require(success, "StorageManager: Transfer failed.");
        }
    }

    function getAgreementReference(bytes32[] memory dataReference, address creator) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(creator, dataReference));
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

    /*
    @dev Only non-zero prices periods are considered to be active. To remove a period, set it's price to 0
    */
    function _setBillingPlan(Offer storage offer, uint64 period, uint64 price) internal {
        require(period <= MAX_BILLING_PERIOD, "StorageManager: Billing period exceed max. length");
        offer.billingPlans[period] = price;
        emit BillingPlanSet(msg.sender, period, price);
    }

    /**
    @dev Helper function for testing timing overloaded in testing contract
    */
    function _time() internal view virtual returns (uint) {
        return now;
    }
}
