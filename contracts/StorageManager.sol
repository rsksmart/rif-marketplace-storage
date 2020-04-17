pragma solidity 0.6.2;

import "./vendor/SafeMath.sol";

/// @title StorageManager
/// @author Rinke Hendriksen <rinke@iovlabs.org>
/// @notice Providers can offer their storage space and list their price and Consumers can take these offers
contract StorageManager {

    using SafeMath for uint256;
    using SafeMath for uint128;
    using SafeMath for uint64;
    uint64 constant private MAX_UINT64 = 18446744073709551615;

    /*
    Offer represents:
     - availableCapacity: the amount of bytes currently offered. When the capacity is zero, already started Agreement can't be prolonged or re-started
     - maximumDuration: the maximum time (in seconds) for which a customer can prepay.
     - billingPlans: maps a billing period to a billing price. When a price is 0, the period is not offered.
     - agreementRegistry: the proposed and accepted Agreement
    */
    struct Offer {
        uint128 availableCapacity;
        uint128 maximumDuration;
        mapping(uint64 => uint64) billingPlans;
        mapping(bytes32 => Agreement) agreementRegistry; // link to agreement that are accepted under this offer
    }

    /*
    Agreement represents:
     - billingPrice: price per byte that is collected per each period. The contract can be cancelled by the proposer every duration seconds since the start.
     - billingPeriod: period how often are funds collected.
     - size: allocated size for the Agreement (in bytes, rounded up)
     - startDate: when the Agreement was accepted
     - numberOfPeriodsDeposited: number of periods (chosenPrice.duration seconds) that is deposited in the contracts.
       At startDate * numberOfPeriodsDeposited seconds the Agreement expires unless topped up in the meantime
     - numberOfPeriodsWithdrawn how many periods are withdrawn from the numberOfPeriodsDeposited. Provider can withdraw every period seconds since the start
     - startDate: when Agreement was accepted
    */
    struct Agreement {
        uint64 billingPrice;
        uint64 billingPeriod;
        uint64 numberOfPeriodsDeposited;
        uint64 numberOfPeriodsWithdrawn;
        uint128 size;
        uint128 startDate;
    }

    // offerRegistry stores the open or closed Offer for provider.
    mapping(address => Offer) public offerRegistry;

    event AvailableCapacitySet(address indexed provider, uint128 capacity);
    event MaximumDurationSet(address indexed provider, uint128 maximumDuration);
    event BillingPlanSet(address indexed provider, uint64 period, uint64 price);
    event MessageEmitted(address indexed provider, bytes32[] message);

    event NewAgreement(
        bytes32[] dataReference,
        address indexed agreementer,
        address indexed provider,
        uint128 size,
        uint64 period,
        uint256 deposited
    );
    event AgreementFundsDeposited(bytes32 indexed agreementReference, uint256 deposited);
    event AgreementStopped(bytes32 indexed agreementReference);
    event AgreementFundsPayout(bytes32 indexed agreementReference);

    /**
    @notice set the availableCapacity, maximumDuration and billingPlans of a Offer.
    @dev
    - Use this function when initiating an Offer or when the users wants to change more than one parameter at once.
    maximumDuration must be smaller or equal to the longest period (NOT verified by smart-contract).
    - Exercise caution with assigning additional capacity when capacity is already taken.
        It may happen that when a lot of capacity is available and we release already-taken capacity, capacity overflows.
        We explicitly allow this overflow to happen on the smart-contract level,
        because the worst thing that can happen is that the provider now has less storage available than planned (in which case he can top it up himself).
        However, take care of this in the client. REF_CAPACITY
    - maximumDuration must be smaller or equal to the longest period (NOT verified by smart-contract).
    - make sure that any period * prices does not cause an overflow, as this can never be accepted (REF_MAX_PRICE) and hence is pointless
    @param capacity the amount of bytes offered.
    If already active before and set to 0, existing contracts can't be prolonged / re-started, no new contracts can be started.
    @param maximumDuration the maximum time (in seconds) for which a proposer can prepay. Prepaid bids can't be cancelled REF1.
    @param billingPeriods the offered periods. Length must be equal to the lenght of billingPrices.
    @param billingPrices the prices for the offered periods. Each entry at index corresponds to the same index at periods. When a price is 0, the matching period is not offered.
    @param message the Provider may include a message (e.g. his nodeID).  Message should be structured such that the first two bits specify the message type, followed with the message). 0x01 == nodeID
    */
    function setOffer(uint128 capacity,
        uint128 maximumDuration,
        uint64[] memory billingPeriods,
        uint64[] memory billingPrices,
        bytes32[] memory message
    ) public {
        Offer storage offer = offerRegistry[msg.sender];
        _setAvailableCapacity(offer, capacity);
        _setMaximumDuration(offer, maximumDuration);
        for(uint8 i = 0; i < billingPeriods.length; i++) {
            _setBillingPlan(offer, billingPeriods[i], billingPrices[i]);
        }
        if (message.length > 0) {
            _emitMessage(message);
        }
    }

    /**
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
    @notice set the billing plans for an Offer.
    @dev
    - setting the price to 0 means that a particular period is not offered, which can be used to remove a period from the offer.
    - make sure that any period * prices does not cause an overflow, as this can never be accepted (REF_MAX_PRICE) and hence is pointless.
    - maximumDuration must be smaller or equal to the longest period (NOT verified by smart-contract).
    @param billingPeriods the offered periods. Length must be equal to billingPrices.
    @param billingPrices the prices for the offered periods. Each entry at index corresponds to the same index at periods. 0 means that the particular period is not offered.
    */
    function setBillingPlans(uint64[] memory billingPeriods, uint64[] memory billingPrices) public {
        Offer storage offer = offerRegistry[msg.sender];
        for(uint8 i = 0; i < billingPeriods.length; i++) {
            _setBillingPlan(offer, billingPeriods[i], billingPrices[i]);
        }
    }

    /**
    @notice set the maximumDuration for a Offer.
    @dev
    - maximumDuration must be smaller or equal to the longest period (NOT verified by smart-contract).
    - make sure that any period is never more than a maximumDuration as this can never be accepted and hence is pointless

    @param maximumDuration the maximum time (in seconds) for which a proposer can prepay. Prepaid bids can't be cancelled REF1.
    */
    function setMaximumDuration(uint128 maximumDuration) public {
        Offer storage offer = offerRegistry[msg.sender];
        _setMaximumDuration(offer, maximumDuration);
    }

    /**
    @param message the Provider may send a message (e.g. his nodeID). Message should be structured such that the first two bits specify the message type, followed with the message). 0x01 == nodeID
    */
    function emitMessage(bytes32[]memory message) public {
        _emitMessage(message);
    }

    /**
    @notice new Agreement for given Offer
    @dev if Agreement was active before, is expired and final payout is not yet done, final payout can be triggered by proposer here.
    The to-be-pinned file's size in bytes (rounded up) must be equal in size to param size.
    @param dataReference the reference to an Data Source, can be several things.
    @param provider the provider from which is proposed to take a Offer.
    @param size the size of the to-be-pinned file in bytes (rounded up).
    @param billingPeriod the chosen period (seconds after which a Agreement can be cancelled and left-over money refunded).
    */
    function newAgreement(bytes32[] memory dataReference, address payable provider, uint128 size, uint64 billingPeriod) public payable {
        require(billingPeriod != 0, "StorageManager: billing period of 0 not allowed");
        bytes32 agreementReference = getAgreementReference(dataReference);
        uint64 billingPrice = offerRegistry[provider].billingPlans[billingPeriod];
        require(billingPrice != 0, "StorageManager: billing price doesn't exist for Offer");
        require(msg.value != 0 && msg.value % billingPrice == 0, "StorageManager: value sent not corresponding to price");
        Offer storage offer = offerRegistry[provider];
        Agreement storage agreement = offer.agreementRegistry[agreementReference];
        // NO_OVERFLOW reasoning. See: REF_DURATION
        bool isPastCurrentEndTime = agreement.startDate + agreement.numberOfPeriodsDeposited * agreement.billingPeriod < now;
        require(
            agreement.startDate == 0 ||
            isPastCurrentEndTime,
            "StorageManager: Agreement already active"
        );
        // If agreement exist from past, lets have clean state. Eq. force withdraw of previous money.
        if(isPastCurrentEndTime && agreement.startDate > 0 ) {
            require(offer.availableCapacity != 0, "StorageManager: provider discontinued service");
            //NO_OVERFLOW reasoning: numberOfPeriodsDeposited always bigger or equal to numberOfPeriodsWithdrawn
            uint256 toTransfer = (agreement.numberOfPeriodsDeposited - agreement.numberOfPeriodsWithdrawn).mul(agreement.billingPrice);
            agreement.numberOfPeriodsWithdrawn = 0;
            provider.transfer(toTransfer); //TODO: transfer is not best practice: https://diligence.consensys.net/blog/2019/09/stop-using-soliditys-transfer-now/
            emit AgreementFundsPayout(agreementReference);
        } else {
            agreement.size = size;
            offer.availableCapacity = uint128(offer.availableCapacity.sub(size));
        }
        //NO_ZERO_DIVISION reasoning: chosenPrice is verified to not be zero in this function call
        uint256 numberOfPeriodsDeposited = msg.value / billingPrice;
        require(
            numberOfPeriodsDeposited.mul(billingPeriod) <= offer.maximumDuration &&
            numberOfPeriodsDeposited <= MAX_UINT64,
            "StorageManager: total period exceeds maximumDuration"
        );
        //NO_OVERFLOW reasoning: verified above
        now.add(numberOfPeriodsDeposited * billingPeriod); // overFlow check. If this doesn't pass, the duration of the offer overflows MAX_UINT64 and the contract may deadlock. REF_DURATION
        numberOfPeriodsDeposited.mul(billingPrice); // overFlow check. If this doesn't pass, we might have issues transfering the maximum amount REF_MAX_TRANSFER
        agreement.billingPrice = billingPrice;
        agreement.billingPeriod = billingPeriod;
        agreement.numberOfPeriodsDeposited = uint64(numberOfPeriodsDeposited);
        agreement.startDate = uint128(now);
        emit NewAgreement(
            dataReference,
            msg.sender,
            provider,
            size,
            billingPeriod,
            msg.value
        );
    }

    /**
    @notice extend the duration of the agreement.
    @dev any safeMath operations in this function don't cause a deadlock, as a possible revert just means we can't prolong the agreement for the desired duration\
    @param dataReference the reference to the to-be-pinned file
    @param provider the address of the provider of the Offer.
    */
    function depositFunds(bytes32[] memory dataReference, address provider) public payable {
        bytes32 agreementReference = getAgreementReference(dataReference);
        Offer storage offer = offerRegistry[provider];
        Agreement storage agreement = offer.agreementRegistry[agreementReference];
        require(offer.availableCapacity != 0, "StorageManager: Offer is terminated");
        require(agreement.startDate != 0, "StorageManager: Agreement not active");
        require(offer.billingPlans[agreement.billingPeriod] != 0, "StorageManager: price not available anymore");
        require(msg.value != 0 && msg.value % agreement.billingPrice == 0, "StorageManager: value sent not corresponding to price");
        //NO_OVERFLOW reasoning: see REF_DURATION
        require((agreement.startDate + agreement.numberOfPeriodsDeposited) * agreement.billingPeriod <= now, "StorageManager: Agreement expired");
        //NO_OVERFLOW reasoning: chosenPrice is verified to not be zero in function call: newRequest
        uint256 numberOfPeriodsDeposited = (msg.value / agreement.size ) / agreement.billingPrice;
        require(
            (
                //NO_OVERFLOW reasoning: billingPeriod can't be zero, startDate always less or equal than now, periodsPast since startDate always less than periodsDeposited (as agreement is not expired, see line 242)
                agreement.numberOfPeriodsDeposited - (now - agreement.startDate) / agreement.billingPeriod // the amount of periods deposited MINUS periods past since the start date (= periods left)
                .add(numberOfPeriodsDeposited)
            ).mul(agreement.billingPeriod) <= offer.maximumDuration &&
            numberOfPeriodsDeposited.add(agreement.numberOfPeriodsDeposited) <= MAX_UINT64,
            "StorageManager: period too long");
        numberOfPeriodsDeposited.mul(agreement.billingPrice); // overFlow check. If this doesn't pass, we might have issues transfering the maximum amount REF_MAX_TRANSFER
        // NO_OVERFLOW reasoning: verified in line above
        agreement.numberOfPeriodsDeposited += uint64(numberOfPeriodsDeposited);
        //NO_OVERFLOW reasoning: verified in function newRequest
        agreement.startDate.add(agreement.numberOfPeriodsDeposited * agreement.billingPeriod); // overFlow check. If this doesn't pass, the duration of the offer overflows MAX_UINT64 and the contract may deadlock. REF_DURATION
        emit AgreementFundsDeposited(agreementReference, msg.value);
    }

    /**
    @notice stops an active agreement.
    @param dataReference the reference to the to-be-pinned file
    @param provider the address of the provider of the Offer.
    */
    function terminateAgreement(bytes32[] memory dataReference, address provider) public payable {
        bytes32 agreementReference = getAgreementReference(dataReference);
        Agreement storage agreement = offerRegistry[provider].agreementRegistry[agreementReference];
        // NO_OVERFLOW reasoning: startDate is always less than now. agreement.billingPeriod is verified not to be 0 in function: newRequest
        uint256 periodsPast = ((now - agreement.startDate) / agreement.billingPeriod) + 1;
        require(
            agreement.numberOfPeriodsWithdrawn + periodsPast <
            agreement.numberOfPeriodsDeposited,
            "StorageManager: agreement expired or in last period"
        );
        agreement.numberOfPeriodsDeposited = 0;
        agreement.numberOfPeriodsWithdrawn = 0;
        //NO_OVERFLOW reasoning: REF_CAPACITY
        offerRegistry[msg.sender].availableCapacity = offerRegistry[msg.sender].availableCapacity + agreement.size;
        agreement.startDate = 0;
        //NO_OVERFLOW reasoning:  verified in "agreement expired" require and see REF_MAX_TRANSFER
        msg.sender.transfer(agreement.numberOfPeriodsDeposited - periodsPast * agreement.billingPrice);
        emit AgreementStopped(agreementReference);
    }

    /**
    @notice payout already earned funds of one or more Agreement
    @dev 
    - any safeMath operations in this function don't cause a deadlock, as a possible revert just means we have to add less agreementReferences
    - Provider must call an expired agreement themselves as soon as the agreement is expired, to add back the capacity.
    @param agreementReferences reference to one or more Agreement
    */
    function payoutFunds(bytes32[] memory agreementReferences) public {
        uint256 toTransfer;
        for(uint8 i = 0; i < agreementReferences.length; i++) {
            Agreement storage agreement = offerRegistry[msg.sender].agreementRegistry[agreementReferences[i]];
            require(agreement.startDate != 0, "StorageManager: Agreement not active");
            // check if agreement is expired
            //NO_OVERFLOW REASONING: see REF_DURATION
            if((agreement.startDate + agreement.numberOfPeriodsDeposited) * agreement.billingPeriod < now) {
                //NO_OVERFLOW reasoning: numberOfPeriodsWithdrawn is always less than or equal to numberOfPeriodsDeposited and REF_MAX_TRANSFER
                toTransfer = toTransfer.add((agreement.numberOfPeriodsDeposited - agreement.numberOfPeriodsWithdrawn) * agreement.billingPrice);
                //reset agreement to clean state
                agreement.numberOfPeriodsWithdrawn = 0;
                agreement.numberOfPeriodsDeposited = 0;
                agreement.startDate = 0;
                // check if Offer is still active
                if(offerRegistry[msg.sender].availableCapacity != 0) {
                    //ALLOW_OVERFLOW reasoning: see: REF_CAPACITY
                    // add back capacity
                    offerRegistry[msg.sender].availableCapacity = offerRegistry[msg.sender].availableCapacity + agreement.size;
                }
            } else {
                // NO_OVERFLOW reasoning: startDate is always less than now. agreement.billingPeriod is verified not to be 0 in function: newRequest
                uint256 periodsPast = (now - agreement.startDate) / agreement.billingPeriod;
                ////NO_OVERFLOW reasoning: numberOfPeriodsWithdrawn is always less than or equal to periodsPast and REF_MAX_TRANSFER
                toTransfer = toTransfer.add((periodsPast - agreement.numberOfPeriodsWithdrawn) * agreement.billingPrice);
                //SAFE_CAST & NO_OVERFLOW reasoning: periodsPast is always less than numberOfPeriodsDeposited (as agreement is not expired), and numberOfPeriodsDeposited is uint64
                agreement.numberOfPeriodsWithdrawn += uint64(periodsPast);
            }
            emit AgreementFundsPayout(agreementReferences[i]);
        }
        msg.sender.transfer(toTransfer);
    }

    function getAgreementReference(bytes32[] memory dataReference) public view returns(bytes32) {
        return keccak256(abi.encodePacked(msg.sender, dataReference));
    }
    function _setAvailableCapacity(Offer storage offer, uint128 capacity) internal {
        offer.availableCapacity = capacity;
        emit AvailableCapacitySet(msg.sender, capacity);
    }

    function _setMaximumDuration(Offer storage offer, uint128 maximumDuration) internal {
        offer.maximumDuration = maximumDuration;
        emit MaximumDurationSet(msg.sender, maximumDuration);
     }

    function _setBillingPlan(Offer storage offer, uint64 period, uint64 price) internal {
        offer.billingPlans[period] = price;
        emit BillingPlanSet(msg.sender, period, price);
    }

    function _emitMessage(bytes32[] memory message) internal {
        emit MessageEmitted(msg.sender, message);
    }
}
