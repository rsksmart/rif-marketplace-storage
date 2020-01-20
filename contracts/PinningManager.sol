pragma solidity ^0.6.1;

import "./vendor/SafeMath.sol";

/// @title PinningManager
/// @author Rinke Hendriksen <rinke@iovlabs.org>
/// @notice Storage providers can offer their storage space and list their price and clients can take these offers
contract PinningManager {

    //**TODO: verify all math operations and use SafeMath where needed. 
    //**TODO: define and emit events

    // using SafeMath for uint256;
    // using SafeMath for uint128;
    uint64 constant MAX_UINT64 = 18446744073709551615;

    // Price signals the price (in Wei) per period (in seconds) 
    //**TODO: Is this struct really needed?
    struct Price {
        uint128 period;
        uint128 price;
    }

    /*
    StorageOffer represents:
     - capacity: the amount of bytes offered. When capacity is zero, already started pinBids can't be prolonged or re-started
     - maximumDuration: the maximum time (in seconds) for which a customer can prepay. 
     ** Question: we can get rid of this (^) parameter and give the provider the power to cancel a pinBid after a period (or x periods) REF1 **
     - prices: maps a period to a price
     - pinBidRegistry: the proposed and accepted pinBids
    */
    struct StorageOffer {
        uint256 capacity;
        uint256 maximumDuration;
        mapping(uint128 => uint128) prices;
        mapping(bytes32 => PinBid) pinBidRegistry; // link to pinning requests that are accepted under this offer
    }
    
    /*
    PinBid represents:
     - chosenPrice: Every duration seconds a amount of x is applied. The contract can be cancelled by the proposer every duration seconds since the start.
     - size: size of the file (in bytes, rounded up)
     - startDate: when the pinBid was accepted
     - numberOfPeriodsDeposited: number of periods (chosenPrice.duration seconds) that is deposited in the contracts. 
       At startDate * numberOfPeriodsDeposited seconds the pinBid expires unless topped up in the meantime
     - numberOfPeriodsWithdrawn how many periods are withdrawn from the numberOfPeriodsDeposited. Provider can withdraw every period seconds since the start
    */
    struct PinBid {
        Price chosenPrice;
        uint256 size; 
        uint256 startDate;
        uint64 numberOfPeriodsDeposited;
        uint64 numberOfPeriodsWithdrawn;
    }

    // offerRegistry stores the open or closed StorageOffers per provider.
    mapping(address => StorageOffer) offerRegistry;

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
    function setStorageOffer(uint256 capacity, uint256 maximumDuration, uint256[] memory periods, uint256[] memory pricesForPeriods) public {
        StorageOffer storage offer = offerRegistry[msg.sender];
        _setCapacity(offer, capacity);
        _setMaximumLength(offer, maximumDuration);
        for(uint8 i = 0; i <= periods.length; i++) {
            _setStoragePrice(offer, periods[i], pricesForPeriods[i]);
        }
    }

    /**
    @notice set the capacity of a StorageOffer.
    If already active before and set to 0, existing contracts can't be prolonged / re-started, no new contracts can be started.
    @param capacity the amount of bytes offered.
    */
    function setStorageCapacity(uint256 capacity) public {
        StorageOffer storage offer = offerRegistry[msg.sender];
        _setCapacity(offer, capacity);
    }

    /**
    @notice set the price for a StorageOffer.
    @param periods the offered periods. Length must be equal to pricesForPeriods.
    @param pricesForPeriods the prices for the offered periods. Each entry at index corresponds to the same index at periods.
    */
    function setStoragePrice(uint256[] memory durations, uint256[] memory pricesForPeriods) public {
        StorageOffer storage offer = offerRegistry[msg.sender];
        for(uint8 i = 0; i <= durations.length; i++) {
            _setStoragePrice(offer, durations[i], prices[i]);
        }
    }

    /**
    @notice set the maximumDuration for a StorageOffer.
    @dev maximumDuration must be smaller or equal to the longest period (NOT verified by smart-contract).
    @param maximumDuration the maximum time (in seconds) for which a proposer can prepay. Prepaid bids can't be cancelled REF1.
    */
    function setMaximumDuration(uint256 maximumDuration) public {
        StorageOffer storage offer = offerRegistry[msg.sender];
        _setMaximumDuration(offer, maximumDuration); 
    }

    /**
    @notice proposes to take a storageOffer. After proposing, an offer must be accepted by provider to become active.
    @dev if pinBid was active before, is expired and final payout is not yet done, final payout can be triggered by proposer here.
    The to-be-pinned file's size in bytes (rounded up) must be equal in size to param size.
    @param fileReference the reference to the to-be-pinned file. 
    @param provider the provider from which is proposed to take a StorageOffer.
    @param size the size of the to-be-pinned file in bytes (rounded up).
    @param period the chosen period (seconds after which a PinBid can be cancelled and left-over money refunded).
    */
    function proposePinning(bytes32 fileReference, address provider, uint256 size, uint256 period) public payable {
        Price price = Price(period, offerRegistry[provider].prices[period]);
        require(price.price != 0, "PinningManager: price doesn't exist for provider");
        require(msg.value != 0 && msg.value % price.price == 0, "PinningManager: value sent not corresponding to price");
        bytes32 pinningReference = getPinBidIdentifier(msg.sender, fileReference);
        PinBid storage pinBid = offerRegistry[offerIdentifier].pinBidRegistry[pinBidIdentifier];
        require(pinBid.startDate == 0 || (pinBid.startDate + (pinBid.numberOfPeriodsDeposited * pinBid.chosenPeriod)) > now, "PinningManager: pinBid already active");
        if(pinBid.startDate + (pinBid.numberOfPeriodsDeposited * pinBid.chosenPeriod) > now) {
            require(offerRegistry[provider].capacity != 0, "PinningManager: provider discontinued service");
            uint256 toTransfer = (pinBid.numberOfPeriodsDeposited - pinBid.numberOfPeriodsWithdrawn) * pinBid.chosenPrice;
            pinBid.numberOfPeriodsWithdrawn = 0;
            pinBid.startDate = 0;
            offerRegistry[msg.sender].capacity = offerRegistry[msg.sender].capacity + pinBid.size;
            provider.transfer(toTransfer);
        } else {
            pinBid.size = size;
        }
        uint256 numberOfPeriodsDeposited = msg.value / price.price;
        require(numberOfPeriods <= MAX_UINT64);
        require(numberOfPeriods * price.period <= offerRegistry[offerIdentifier].maximumDuration, "PinningManager: period too long");
        pinBid.chosenPeriod = price.period;
        pinBid.chosenPrice = price.price;
        pinBid.numberOfPeriodsDeposited = numberOfPeriodsDeposited;
        // emit event
    }

    /**
    @notice stops a PinBid before it is accepted and transfers all money paid in.
    @param fileReference the reference to the not-anymore-to-be-pinned file. 
    */
    function stopPinningBefore(bytes32 fileReference) public {
        bytes32 pinningReference = getPinBidIdentifier(msg.sender, fileReference);
        PinBid storage pinBid = offerRegistry[offerIdentifier].pinBidRegistry[pinBidIdentifier];
        uint256 toTransfer = pinBid.numberOfPeriodsDeposited * pinBid.chosenPrice;
        pinBid.numberOfPeriodsDeposited = 0;
        msg.sender.transfer(toTransfer);
        // emit event
    }

    /**
    @notice accepts a PinBid. From now on, the provider is responsible for pinning the file
    @param pinningReference the keccak256 hash of the bidder and the fileReference (see: getPinBidIdentifier)
    */
    function acceptPinning(bytes32 pinningReference) public {
        PinBid storage pinBid = offerRegistry[msg.sender].pinBidRegistry[pinningReference];
        require(pinBid.numberOfPeriodsDeposited != 0);
        pinBid.startDate = now;
        offerRegistry[msg.sender].capacity = offerRegistry[msg.sender].capacity.sub(pinBid.size);
        // emit event
    }

    // TODO: is it desirable that any party can top up? Right now, only the original proposer can do this. I can make it all parties with some modifications
    /**
    @notice extend the duration of the PinBid.
    @param fileReference the reference to the already-pinned file.
    @param provider the address of the provider of the StorageOffer.
    */
    function topUpPinning(bytes32 fileReference, address provider) public payable {
        bytes32 pinningReference = getPinBidIdentifier(proposer, fileReference);
        PinBid storage pinBid = offerRegistry[offerIdentifier].pinBidRegistry[pinBidIdentifier];
        require(offerRegistry[provider].capacity != 0, "PinningManager: provider discontinued service");
        require(pinBid.startDate != 0, "PinningManager: pinBid not active");
        require(offerRegistry[provider].prices[pinBid.period] != 0, "PinningManager: price not available anymore");
        require(msg.value != 0 && msg.value % pinBid.chosenPrice == 0, "PinningManager: value sent not corresponding to price");
        require(pinBid.startDate + (pinBid.numberOfPeriodsDeposited * pinBid.chosenPeriod) <= now, "PinningManager: pinBid expired");
        uint256 numberOfPeriods = msg.value / pinBid.chosenPrice;
        // periodsPast = (now - pinBid.startDate) /  pinBid.chosenPeriod
        // periodsLeft = pinBid.numberOfPeriodsDeposited - periodsPast;
        require(((pinBid.numberOfPeriodsDeposited - ((now - pinBid.startDate) /  pinBid.chosenPeriod)) + numberOfPeriods) * pinBid.chosenPeriod <= pinBid.maximumDuration, "PinningManager: period too long");
        pinBid.numberOfPeriodsDeposited += numberOfPeriods;
        // emit event
    }

    /**
    @notice stops an active PinBid.
    @param fileReference the reference to the not-anymore-to-pin file.
    @param provider the address of the provider of the StorageOffer.
    */
    function stopPinningDuring(bytes32 fileReference, address provider) public payable {
        bytes32 pinningReference = getPinBidIdentifier(msg.sender, fileReference);
        PinBid storage pinBid = offerRegistry[provider].pinBidRegistry[pinningReference];
        uint periodsPast = (now - pinBid.startDate) /  pinBid.chosenPeriod + 1;
        uint periodsLeft = pinBid.numberOfPeriodsDeposited - periodsPast;
        pinBid.numberOfPeriodsDeposited = 0;
        pinBid.numberOfPeriodsWithdrawn = 0;
        offerRegistry[msg.sender].capacity = offerRegistry[msg.sender].capacity + pinBid.size;
        pinBid.startDate = 0;
        msg.sender.transfer(periodsLeft * pinBid.chosenPrice);
        // emit event
    }

    /**
    @notice withdraws the to-withdraw balance of one or more PinBids
    @param pinningReferences reference to one or more PinBids
    */
    function withdraw(bytes32[] pinningReferences) public {
        uint toTransfer;
        for(uint8 i = 0; i <= durations.length; i++) {
            PinBid storage pinBid = offerRegistry[msg.sender].pinBidRegistry[pinningReference];
            require(pinBid.startDate != 0, "PinningManager: pinBid not active");
            periodsPast = (now - pinBid.startDate) /  pinBid.chosenPeriod;
            pinBid.numberOfPeriodsWithdrawn += periodsPast;
            if(pinBid.numberOfPeriodsWithdrawn + periodsPast >= pinBid.numberOfPeriodsDeposited && offerRegistry[msg.sender].capacity != 0) {
                toTransfer += pinBid.numberOfPeriodsDeposited - pinBid.numberOfPeriodsWithdrawn;
                pinBid.numberOfPeriodsWithdrawn = 0;
                pinBid.numberOfPeriodsDeposited = 0;
                offerRegistry[msg.sender].capacity = offerRegistry[msg.sender].capacity + pinBid.size;
                pinBid.startDate = 0;
            } else {
                toTransfer += periodsPast - pinBid.numberOfPeriodsWithdrawn;
            }
        }
        msg.sender.transfer(toTransfer);
        // emit event
    }

    function _setCapacity(StorageOffer storage offer, uint256 newCapacity) internal {
        offer.capacity = newCapacity;
        // emit event
    }

    function _setMaximumDuration(offer, maximumDuration) internal {
         offer.maximumDuration = maximumDuration;
         // emit event
     }

    function _setStoragePrice(StorageOffer storage offer, uint256 price, uint256 period) internal {
        require(offer.maximumDuration >= period); //TODO: maybe we can remove this, if there is no attack vector.
        offer.prices[period] = price;
        // emit event
    }

    function getPinBidIdentifier(address bidder, bytes32 fileIdentifier) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(bidder, fileIdentifier));
    }
}