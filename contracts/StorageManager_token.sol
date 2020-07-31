pragma solidity 0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title StorageManagerToken
/// @author Rinke Hendriksen <rinke@iovlabs.org>
/// @author Adam Uhlir <adam@iovlabs.org>
/// @notice Providers can offer their storage space and list their price and Consumers can take these offers
contract StorageManagerToken {

    using SafeMath for uint256;
    using SafeMath for uint128;
    using SafeMath for uint64;
    uint64 constant private MAX_BILLING_PERIOD = 15552000; // 6 * 30 days ~~ 6 months

    modifier activeOffer(address provider){
        Offer storage offer = offerRegistry[provider];
        require(offer.totalCapacity != 0, "StorageManager: Offer for this Provider doesn't exist");
        _;
    }

    modifier existingAgreement(bytes32[] memory dataReference, address provider){
        Offer storage offer = offerRegistry[provider];
        bytes32 agreementReference = getAgreementReference(dataReference, msg.sender);
        Agreement storage agreement = offer.agreementRegistry[agreementReference];
        require(agreement.size != 0, "StorageManager: Agreement for this Offer doesn't exist");
        _;
    }

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

    // the reference to the token used by this contract
    ERC20 public token;

    // offerRegistry stores the open or closed Offer for provider.
    mapping(address => Offer) public offerRegistry;

    event TotalCapacitySet(address indexed provider, uint128 capacity);
    event BillingPlanSet(address indexed provider, uint64 period, uint64 price);
    event MessageEmitted(address indexed provider, bytes32[] message);

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

    /// @param _token the address of the token which is used by this smart contract
    constructor (address _token) public {
        token = ERC20(_token);
    }

    /**
    >> FOR PROVIDER
    @notice set the totalCapacity and billingPlans of a Offer.
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
        setTotalCapacity(capacity);
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
    @notice stops the Offer. It sets
    @dev no new Agreement can be created and no existing Agreement can be prolonged. All existing Agreement are still valid for the amount of periods still deposited.
    */
    function terminateOffer() public activeOffer(msg.sender) {
        Offer storage offer = offerRegistry[msg.sender];
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
    function setBillingPlans(uint64[] memory billingPeriods, uint64[] memory billingPrices) public activeOffer(msg.sender) {
        require(billingPeriods.length > 0, "StorageManager: Offer needs some billing plans");
        require(billingPeriods.length == billingPrices.length, "StorageManager: Billing plans array length has to equal to billing prices");
        Offer storage offer = offerRegistry[msg.sender];
        for (uint8 i = 0; i < billingPeriods.length; i++) {
            _setBillingPlan(offer, billingPeriods[i], billingPrices[i]);
        }
    }

    /**
    >> FOR PROVIDER
    @param message the Provider may send a message (e.g. his nodeID). Message should be structured such that the first two bits specify the message type, followed with the message). 0x01 == nodeID
    */
    function emitMessage(bytes32[]memory message) public {
        _emitMessage(message);
    }

    /**
    >> FOR CONSUMER
    @notice new Agreement for given Offer, you must call approve with the parameters (spender = address(this), amount = value) for this call to succeed
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
    function newAgreement(bytes32[] memory dataReference, address provider, uint128 size, uint64 billingPeriod, bytes32[] memory agreementsReferencesToBePayedOut, uint256 value) public activeOffer(provider) {
        require(billingPeriod != 0, "StorageManager: Billing period of 0 not allowed");
        require(size > 0, "StorageManager: Size has to be bigger then 0");

        Offer storage offer = offerRegistry[provider];
        bytes32 agreementReference = getAgreementReference(dataReference, msg.sender);
        Agreement storage agreement = offer.agreementRegistry[agreementReference];
        require(agreement.lastPayoutDate == 0, "StorageManager: Agreement already active");

        uint64 billingPrice = offer.billingPlans[billingPeriod];
        require(billingPrice != 0, "StorageManager: Billing price doesn't exist for Offer");

        // attempt to transfer tokens to this contract. NOTE: to succeed this call, the caller must have called approve on the token contract first
        _transferToMe(msg.sender, value);
        // Adding to previous availableFunds as the agreement could have been expired
        // and Consumer is reactivating it, so in order not to loose any previous funds.
        agreement.availableFunds = agreement.availableFunds.add(value);
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
            _payoutFunds(agreementsReferencesToBePayedOut, provider);
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
    @notice deposits new funds to the Agreement, you must call approve with the parameters (spender = address(this), amount = value) for this call to succeed
    @dev
        - depositing funds to Agreement that is linked to terminated Offer is not possible
    @param dataReference data reference where should be deposited funds.
    @param provider the address of the provider of the Offer.
    */
    function depositFunds(bytes32[] memory dataReference, address provider, uint256 value) public activeOffer(provider) existingAgreement(dataReference, provider) {
        bytes32 agreementReference = getAgreementReference(dataReference, msg.sender);
        Offer storage offer = offerRegistry[provider];
        Agreement storage agreement = offer.agreementRegistry[agreementReference];

        require(agreement.lastPayoutDate != 0, "StorageManager: Agreement not active");
        require(offer.billingPlans[agreement.billingPeriod] != 0, "StorageManager: Price not available anymore");

        _transferToMe(msg.sender, value);
        agreement.availableFunds = agreement.availableFunds.add(value);
        emit AgreementFundsDeposited(agreementReference, value);
    }

    /**
    >> FOR CONSUMER
    @notice withdraw funds from Agreement.
    @dev
        - if amount is zero then all withdrawable funds are transferred (eq. all available funds minus funds for still non-payed out periods and current period)
        - if Agreement is terminated Consumer can withdraw all remaining funds
        - if the call to _transfer ever reverts, this means that the internal accounting of the contract made a mistake or that we got hacked.
    @param dataReference the data reference of agreement to be funds withdrawn from
    @param provider the address of the provider of the Offer.
    */
    function withdrawFunds(bytes32[] memory dataReference, address provider, uint256 amount) public existingAgreement(dataReference, provider) {
        Offer storage offer = offerRegistry[provider];
        bytes32 agreementReference = getAgreementReference(dataReference, msg.sender);
        Agreement storage agreement = offer.agreementRegistry[agreementReference];

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

        // if this ever reverts, we have a big problem as this means that somebody transfered more money out of the contract than it should
        _transfer(msg.sender, amount);
        emit AgreementFundsWithdrawn(agreementReference, amount);
    }

    /**
    >> FOR PROVIDER
    @notice payout already earned funds of one or more Agreement
    @dev 
    - Provider must call an expired agreement themselves as soon as the agreement is expired, to add back the capacity to their Offer.
    - if the call to _transfer ever reverts, this means that the internal accounting of the contract made a mistake or that we got hacked. 
    @param agreementReferences reference to one or more Agreement
    */
    function payoutFunds(bytes32[] memory agreementReferences) public {
        _payoutFunds(agreementReferences, msg.sender);
    }

    function _payoutFunds(bytes32[] memory agreementReferences, address provider) internal {
        Offer storage offer = offerRegistry[provider];
        uint256 toTransfer = 0;
        for (uint8 i = 0; i < agreementReferences.length; i++) {
            Agreement storage agreement = offer.agreementRegistry[agreementReferences[i]];
            require(agreement.size != 0, "StorageManager: Agreement for this Offer doesn't exist");
            // Was already payed out and terminated
            require(agreement.lastPayoutDate != 0, "StorageManager: Agreement is inactive");

            uint256 spentFunds = _calculateSpentFunds(agreement);
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

        require(toTransfer > 0, "StorageManager: Nothing to withdraw");
        // if this ever reverts, we have a big problem as this means that somebody transfered more money out of the contract than it should
        _transfer(provider, toTransfer);
    }

    function getAgreementReference(bytes32[] memory dataReference, address creator) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(creator, dataReference));
    }

    // in order to succesfully call this function, the caller must first have called approve (spender = address(this), amount = _amount)
    function _transferToMe(address from, uint256 _amount) internal {
        require(token.transferFrom(from, address(this), _amount), "StorageManager: could not transfer token to this contract");
    }

    function _transfer(address to, uint256 amount) internal {
        require(token.transfer(to, amount), "StorageManager: could not transfer tokens");
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
