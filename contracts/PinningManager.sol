pragma solidity ^0.5.12;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/// @title PinningManager
/// @author Rinke Hendriksen <rinke@iovlabs.org>
/// @notice Storage providers can offer their storage space and list their price (based on a relationship to time) and clients can take these offers
contract PinningManager {

    using SafeMath for uint256;

    /*
    Price represents a {duration, totalValue} tuple, where totalValue is the amount which must be paid to pin a file for duration
    */
    struct Price {
        uint256 duration;
        uint256 price;
    }

    /*
    Offer represents:
     - total capacity of storage space (in bytes)
     - an array of Price tuples
     - the pinBids (identified by a bytes32 hash) registered under the offer
    */
    struct StorageOffer {
        uint256 capacity;
        Price[] prices;
        mapping(bytes32 => PinBid) pinBidRegistry;
    }

    /*
    PinBid represents:
     - size of the file
     - startDate when the pinBid was initiated
     - (Wei) deposited
     - (Wei) withdrawn
    */
    struct PinBid {
        uint256 size;
        uint256 startDate;
        uint256 deposited;
        uint256 withdrawn;
    }

    // the offerRegistry maps an offerIdentifier (keccak256(offerProvider, offerCount)) to an offer
    mapping(bytes32 => StorageOffer) offerRegistry;
    // how many storage offers the provider ever registered, only the most recent can be accepted
    mapping(address => uint256) offerCounter;

    event StorageOfferMade(bytes32 indexed offerIdentifier, address indexed offerProvider, uint256[] durations, uint256[] prices, uint256 capacity);
    event PinBidMade(bytes32 indexed offerIdentifier, bytes32 indexed pinBidIdentifier, uint256 size, uint256 startDate, uint256 totalDeposited);
    event PinBidStopped(bytes32 indexed offerIdentifier, bytes32 indexed pinBidIdentifier, address indexed offerProvider, bytes32 reasons);

    /**
    * @notice makes an offer
    */
    function makeStorageOffer(uint256 _capacity, uint256[] memory durations, uint256[] memory prices) public {
        bytes32 offerIdentifier = getOfferIdentifier(msg.sender, offerCounter[msg.sender]+1);
        StorageOffer storage offer = offerRegistry[offerIdentifier];
        offer.capacity = _capacity;
        if(durations.length != 0) {
            require(durations.length == prices.length && durations.length <= 256, "PinningManager, duration and value not equal");
            offer.prices[0] = Price({duration: durations[0], price: prices[0]});
            for(uint8 i = 1; i <= durations.length; i++) {
                require(durations[i] > durations[i-1], "PinningManager, duration not monotonically increasing");
                require(prices[i] >= prices[i-1]);
                offer.prices[i] = Price({duration: durations[i], price: prices[i]});
            }
            offerCounter[msg.sender] += 1;
        } else {
            require(offerCounter[msg.sender] != 0, "PinningManager, cannot make first offer without price information");
        }
        emit StorageOfferMade(offerIdentifier, msg.sender, durations, prices, _capacity);
    }

    /**
    * @notice accepts an offer 
    */
    function makePinBid(address payable offerProvider, uint256 size, bytes32 pinBidIdentifier) public payable {
        bytes32 offerIdentifier = getOfferIdentifier(offerProvider, offerCounter[offerProvider]);
        PinBid storage pinBid =  offerRegistry[offerIdentifier].pinBidRegistry[pinBidIdentifier];
        // we accept a contract when we don't ever have accepted this offer before, or when we previously have accepted this offer, but it was expired in the meantime.
        // pinBid was active before and final payout not done
        if(pinBid.deposited != 0 && pinBid.deposited != pinBid.withdrawn) {
            uint256 duration = calculateDuration(offerIdentifier, pinBid.deposited);
            require(pinBid.startDate + duration <= now, "PinningManager: pinBid not expired");
            offerProvider.transfer(pinBid.deposited - pinBid.withdrawn);
            offerRegistry[offerIdentifier].capacity.add(size); // release capacity
        }
        offerRegistry[offerIdentifier].capacity.sub(size); // take capacity, revert if size > capacity
        pinBid.size = size;
        pinBid.startDate = now;
        pinBid.deposited = msg.value;
        pinBid.withdrawn = 0;
        emit PinBidMade(offerIdentifier, pinBidIdentifier, size, now, msg.value);
    }

    function prolongContract(address offerProvider, bytes32 pinBidIdentifier) public payable {
        bytes32 offerIdentifier = getOfferIdentifier(offerProvider, offerCounter[offerProvider]); // we take the latest offer
        PinBid storage pinBid = offerRegistry[offerIdentifier].pinBidRegistry[pinBidIdentifier];
        uint256 duration = calculateDuration(offerIdentifier, pinBid.deposited);
        require(pinBid.startDate + duration > now, "PinningManager: pinBid expired, pinBidIdentifier incorrect or offerProvider listed new offer"); // offer must not be expired yet
        require(offerRegistry[offerIdentifier].capacity >= pinBid.size, "PinningManager: capacity unavailable"); // capacity must be still available
        pinBid.deposited += msg.value;
        emit PinBidMade(offerIdentifier, pinBidIdentifier,  0, now, pinBid.deposited);
    }

    function requestPayout(uint256 offerCount, bytes32 pinBidIdentifier, uint256 amount) public {
        bytes32 offerIdentifier = getOfferIdentifier(msg.sender, offerCount);
        PinBid storage pinBid =  offerRegistry[offerIdentifier].pinBidRegistry[pinBidIdentifier];
        // if expired, we can transfer the full amount
        if(pinBid.startDate + calculateDuration(offerIdentifier, pinBid.deposited) <= now ) {
            pinBid.deposited = 0;
            offerRegistry[offerIdentifier].capacity.add(pinBid.size);
            msg.sender.transfer(pinBid.deposited - pinBid.withdrawn);
            return;
        } else {
            // the duration (based on amount) should have passed already
            require(calculateDuration(offerIdentifier, amount) <= now - pinBid.startDate);
            // we cannot withdraw more than is deposited (TODO: this condition can probably never be false)
            require(pinBid.withdrawn <= pinBid.deposited);
            pinBid.withdrawn += amount;
            msg.sender.transfer(amount);
        }
    }

    function cancelContract(bytes32 offerIdentifier, uint256 offerCount, bytes32 pinBidIdentifier, bytes32 reasons) public {
        require(offerIdentifier == getOfferIdentifier(msg.sender, offerCount)); // only offerProvider may do this
        emit PinBidStopped(offerIdentifier, pinBidIdentifier, msg.sender, reasons);
    }    

    function calculateDuration(bytes32 offerIdentifier, uint256 price) public view returns(uint256) {
        Price[] memory prices = offerRegistry[offerIdentifier].prices;
        for(uint8 i = 0; i < prices.length; i++) {
            if(price < prices[i].price) {
                if(i == 0) {
                    uint256 durationDelta = prices[i].duration;
                    uint256 priceDelta = prices[i].price;
                    return (price * durationDelta) / priceDelta;
                } else {
                    uint256 durationDelta = prices[i].duration - prices[i-1].duration;
                    uint256 priceDelta = prices[i].price - prices[i-1].price;
                    return prices[i-1].duration + ((price - prices[i-1].price) * durationDelta) / priceDelta;
                }
            } else if(price == prices[i].price) {
                return prices[i].duration;
            }
        }
        uint256 durationDelta = prices[prices.length].duration - prices[prices.length-1].duration;
        uint256 priceDelta = prices[prices.length].price - prices[prices.length-1].price;
        return prices[prices.length].duration + ((price - prices[prices.length-1].price) * durationDelta) / priceDelta;
    }

    // an offerIdentifier comprises the offerProvider and a count, to allow updating an offer, but keeping the same identity (offerProvider)
    function getOfferIdentifier(address offerProvider, uint256 offerCount) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(offerProvider, offerCount));
    }
}