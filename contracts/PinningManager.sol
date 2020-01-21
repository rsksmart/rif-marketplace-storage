pragma solidity ^0.6.1;

import "./vendor/SafeMath.sol";

/// @title PinningManager
/// @author Rinke Hendriksen <rinke@iovlabs.org>
/// @notice Storage providers can offer their storage space and list their price and clients can take these offers
contract PinningManager {

    //**TODO: verify all math operations and use SafeMath where needed.
    //**TODO: make a seperate contract per request?
    // using SafeMath for uint256;
    // using SafeMath for uint128;
    uint64 constant MAX_UINT64 = 18446744073709551615;

    /*
    StorageOffer represents:
     - capacity: the amount of bytes offered. When capacity is zero, already started Requests can't be prolonged or re-started
     - maximumDuration: the maximum time (in seconds) for which a customer can prepay.
     - prices: maps a period to a price
     - RequestRegistry: the proposed and accepted Requests
    */
    struct StorageOffer {
        uint128 capacity;
        uint128 maximumDuration;
        mapping(uint64 => uint64) prices;
        mapping(bytes32 => Request) RequestRegistry; // link to pinning requests that are accepted under this offer
    }

    /*
    Request represents:
     - chosenPrice: Every duration seconds a amount of x is applied. The contract can be cancelled by the proposer every duration seconds since the start.
     - size: size of the file (in bytes, rounded up)
     - startDate: when the Request was accepted
     - numberOfPeriodsDeposited: number of periods (chosenPrice.duration seconds) that is deposited in the contracts.
       At startDate * numberOfPeriodsDeposited seconds the Request expires unless topped up in the meantime
     - numberOfPeriodsWithdrawn how many periods are withdrawn from the numberOfPeriodsDeposited. Provider can withdraw every period seconds since the start
    */
    struct Request {
        uint64 chosenPrice;
        uint64 chosenPeriod;
        uint64 numberOfPeriodsDeposited;
        uint64 numberOfPeriodsWithdrawn;
        uint128 size;
        uint128 startDate;
    }

    // offerRegistry stores the open or closed StorageOffers per provider.
    mapping(address => StorageOffer) offerRegistry;

    event CapacitySet(address indexed storer, uint256 capacity);
    event MaximumDurationSet(address indexed storer, uint128 maximumDuration);
    event PriceSet(address indexed storer, uint64 period, uint64 price);

    event RequestMade(
        bytes32 indexed fileReference,
        address indexed requester,
        address indexed provider,
        uint128 size,
        uint64 period,
        uint256 deposited
    );
    event RequestTopUp(bytes32 indexed requestReference, uint256 deposited);
    event RequestAccepted(bytes32 indexed requestReference);
    event RequestStopped(bytes32 indexed requestReference);

    event EarningsWithdrawn(bytes32 indexed requestReference);

    /**
    @notice set the capacity, maximumDuration and price of a StorageOffer.
    @dev use this function when initiating a storage offer or when the users wants to change more than one parameter at once. TODO: gas price comparison.
    maximumDuration must be smaller or equal to the longest period (NOT verified by smart-contract).
    @param capacity the amount of bytes offered.
    If already active before and set to 0, existing contracts can't be prolonged / re-started, no new contracts can be started.
    @param maximumDuration the maximum time (in seconds) for which a proposer can prepay. Prepaid bids can't be cancelled REF1.
    @param periods the offered periods. Length must be equal to pricesForPeriods.
    @param pricesForPeriods the prices for the offered periods. Each entry at index corresponds to the same index at periods.
    */
    function setStorageOffer(uint128 capacity, uint128 maximumDuration, uint64[] memory periods, uint64[] memory pricesForPeriods) public {
        StorageOffer storage offer = offerRegistry[msg.sender];
        _setCapacity(offer, capacity);
        _setMaximumDuration(offer, maximumDuration);
        for(uint8 i = 0; i <= periods.length; i++) {
            _setStoragePrice(offer, periods[i], pricesForPeriods[i]);
        }
    }

    /**
    @notice set the capacity of a StorageOffer.
    If already active before and set to 0, existing contracts can't be prolonged / re-started, no new contracts can be started.
    @param capacity the amount of bytes offered.
    */
    function setStorageCapacity(uint128 capacity) public {
        StorageOffer storage offer = offerRegistry[msg.sender];
        _setCapacity(offer, capacity);
    }

    /**
    @notice set the price for a StorageOffer.
    @param periods the offered periods. Length must be equal to pricesForPeriods.
    @param pricesForPeriods the prices for the offered periods. Each entry at index corresponds to the same index at periods.
    */
    function setStoragePrice(uint64[] memory periods, uint64[] memory pricesForPeriods) public {
        StorageOffer storage offer = offerRegistry[msg.sender];
        for(uint8 i = 0; i <= periods.length; i++) {
            _setStoragePrice(offer, periods[i], pricesForPeriods[i]);
        }
    }

    /**
    @notice set the maximumDuration for a StorageOffer.
    @dev maximumDuration must be smaller or equal to the longest period (NOT verified by smart-contract).
    @param maximumDuration the maximum time (in seconds) for which a proposer can prepay. Prepaid bids can't be cancelled REF1.
    */
    function setMaximumDuration(uint128 maximumDuration) public {
        StorageOffer storage offer = offerRegistry[msg.sender];
        _setMaximumDuration(offer, maximumDuration);
    }

    /**
    @notice request to fill a storageOffer. After requesting, an offer must be accepted by provider to become active.
    @dev if Request was active before, is expired and final payout is not yet done, final payout can be triggered by proposer here.
    The to-be-pinned file's size in bytes (rounded up) must be equal in size to param size.
    @param fileReference the reference to the to-be-pinned file.
    @param provider the provider from which is proposed to take a StorageOffer.
    @param size the size of the to-be-pinned file in bytes (rounded up).
    @param period the chosen period (seconds after which a Request can be cancelled and left-over money refunded).
    */
    function newRequest(bytes32 fileReference, address payable provider, uint128 size, uint64 period) public payable {
        bytes32 requestReference = getRequestReference(msg.sender, fileReference);
        uint64 chosenPrice = offerRegistry[provider].prices[period];
        require(chosenPrice != 0, "PinningManager: price doesn't exist for provider");
        require(msg.value != 0 && msg.value % chosenPrice == 0, "PinningManager: value sent not corresponding to price");
        StorageOffer storage offer = offerRegistry[provider];
        Request storage request = offer.RequestRegistry[fileReference];
        require(
            request.startDate == 0 ||
            request.startDate + (request.numberOfPeriodsDeposited * request.chosenPeriod) > now,
            "PinningManager: Request already active"
        );
        if(request.startDate + (request.numberOfPeriodsDeposited * request.chosenPeriod) > now) {
            require(offer.capacity != 0, "PinningManager: provider discontinued service");
            uint256 toTransfer = (request.numberOfPeriodsDeposited - request.numberOfPeriodsWithdrawn) * request.chosenPrice;
            request.numberOfPeriodsWithdrawn = 0;
            request.startDate = 0;
            offerRegistry[msg.sender].capacity = offerRegistry[msg.sender].capacity + request.size;
            provider.transfer(toTransfer);
            emit EarningsWithdrawn(requestReference);
        } else {
            request.size = size;
        }
        uint256 numberOfPeriodsDeposited = msg.value / chosenPrice;
        require(
            numberOfPeriodsDeposited * period <= offer.maximumDuration ||
            numberOfPeriodsDeposited <= MAX_UINT64,
            "PinningManager: period too long"
        );
        request.chosenPrice = chosenPrice;
        request.numberOfPeriodsDeposited = uint64(numberOfPeriodsDeposited);
        emit RequestMade(
            fileReference,
            msg.sender,
            provider,
            size,
            period,
            msg.value
        );
    }

    // ** TODO: instead of stopping, we can also reduce the deposited amount partly
    /**
    @notice stops a Request before it is accepted and transfers all money paid in.
    @param fileReference the reference to the not-anymore-to-be-pinned file.
    */
    function stopRequestBefore(bytes32 fileReference, address provider) public {
        bytes32 requestReference = getRequestReference(msg.sender, fileReference);
        Request storage request = offerRegistry[provider].RequestRegistry[requestReference];
        uint256 toTransfer = request.numberOfPeriodsDeposited * request.chosenPrice;
        request.numberOfPeriodsDeposited = 0;
        msg.sender.transfer(toTransfer);
        emit RequestStopped(requestReference);
    }

    // **TODO: stopping request as a provider, mentioning reason

    /**
    @notice accepts a request. From now on, the provider is responsible for pinning the file
    @param requestReference the keccak256 hash of the bidder and the fileReference (see: getRequestReference)
    */
    function acceptRequest(bytes32 requestReference) public {
        Request storage request = offerRegistry[msg.sender].RequestRegistry[requestReference];
        require(request.numberOfPeriodsDeposited != 0);
        request.startDate = uint128(now);
        offerRegistry[msg.sender].capacity = offerRegistry[msg.sender].capacity - request.size;
        emit RequestAccepted(requestReference);
    }

    // TODO: is it desirable that any party can top up? Right now, only the original proposer can do this. I can make it all parties with some modifications
    /**
    @notice extend the duration of the request.
    @param fileReference the reference to the already-pinned file.
    @param provider the address of the provider of the StorageOffer.
    */
    function topUpRequest(bytes32 fileReference, address provider) public payable {
        bytes32 requestReference = getRequestReference(msg.sender, fileReference);
        StorageOffer storage offer = offerRegistry[provider];
        Request storage request = offer.RequestRegistry[requestReference];
        require(offer.capacity != 0, "PinningManager: provider discontinued service");
        require(request.startDate != 0, "PinningManager: Request not active");
        require(offer.prices[request.chosenPeriod] != 0, "PinningManager: price not available anymore");
        require(msg.value != 0 && msg.value % request.chosenPrice == 0, "PinningManager: value sent not corresponding to price");
        require(request.startDate + (request.numberOfPeriodsDeposited * request.chosenPeriod) <= now, "PinningManager: Request expired");
        uint64 numberOfPeriods = uint64(msg.value / request.chosenPrice);
        // periodsPast = (now - request.startDate) /  request.chosenPeriod
        // periodsLeft = request.numberOfPeriodsDeposited - periodsPast;
        require(
            (
                request.numberOfPeriodsDeposited -
                (now - request.startDate) / request.chosenPeriod +
                numberOfPeriods
            ) * request.chosenPeriod <= offer.maximumDuration,
            "PinningManager: period too long");
        request.numberOfPeriodsDeposited += numberOfPeriods;
        emit RequestTopUp(requestReference, msg.value);
    }

    /**
    @notice stops an active request.
    @param fileReference the reference to the not-anymore-to-pin file.
    @param provider the address of the provider of the StorageOffer.
    */
    function stopRequestDuring(bytes32 fileReference, address provider) public payable {
        bytes32 requestReference = getRequestReference(msg.sender, fileReference);
        Request storage request = offerRegistry[provider].RequestRegistry[requestReference];
        uint periodsPast = (now - request.startDate) /  request.chosenPeriod + 1;
        uint periodsLeft = request.numberOfPeriodsDeposited - periodsPast;
        request.numberOfPeriodsDeposited = 0;
        request.numberOfPeriodsWithdrawn = 0;
        offerRegistry[msg.sender].capacity = offerRegistry[msg.sender].capacity + request.size;
        request.startDate = 0;
        msg.sender.transfer(periodsLeft * request.chosenPrice);
        emit RequestStopped(requestReference);
    }

    /**
    @notice withdraws the to-withdraw balance of one or more Requests
    @param requestReferences reference to one or more Requests
    */
    function withdrawEarnings(bytes32[] memory requestReferences) public {
        uint toTransfer;
        for(uint8 i = 0; i <= requestReferences.length; i++) {
            Request storage request = offerRegistry[msg.sender].RequestRegistry[requestReferences[i]];
            require(request.startDate != 0, "PinningManager: Request not active");
            //TODO: casting to 128 doesn't work if now is too far away from the startDate
            uint64 periodsPast = uint64((now - request.startDate) /  request.chosenPeriod);
            request.numberOfPeriodsWithdrawn += periodsPast;
            if(request.numberOfPeriodsWithdrawn + periodsPast >= request.numberOfPeriodsDeposited && offerRegistry[msg.sender].capacity != 0) {
                toTransfer += request.numberOfPeriodsDeposited - request.numberOfPeriodsWithdrawn;
                request.numberOfPeriodsWithdrawn = 0;
                request.numberOfPeriodsDeposited = 0;
                offerRegistry[msg.sender].capacity = offerRegistry[msg.sender].capacity + request.size;
                request.startDate = 0;
            } else {
                toTransfer += periodsPast - request.numberOfPeriodsWithdrawn;
            }
            emit EarningsWithdrawn(requestReferences[i]);
        }
        msg.sender.transfer(toTransfer);
    }

    function _setCapacity(StorageOffer storage offer, uint128 capacity) internal {
        offer.capacity = capacity;
        emit CapacitySet(msg.sender, capacity);
    }

    function _setMaximumDuration(StorageOffer storage offer, uint128 maximumDuration) internal {
        offer.maximumDuration = maximumDuration;
        emit MaximumDurationSet(msg.sender, maximumDuration);
     }

    function _setStoragePrice(StorageOffer storage offer, uint64 period, uint64 price) internal {
        require(offer.maximumDuration >= period); //TODO: maybe we can remove this, if there is no attack vector.
        offer.prices[period] = price;
        emit PriceSet(msg.sender, period, price);
    }

    function getRequestReference(address bidder, bytes32 fileIdentifier) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(bidder, fileIdentifier));
    }
}