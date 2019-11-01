import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./vendor/Equation.sol";
pragma solidity ^0.5.9;

/// @title PinningManager
/// @author Rinke Hendriksen <rinke@iovlabs.org>
/// @notice Storage providers can offer their storage space and list their price (based on a relationship to time) and clients can take these offers
contract PinningManager {

    using SafeMath for uint256;
    using Equation for Equation.Node[];

    /*
    Offer represents:
     - total capacity of storage space (in bytes)
     - an equation that calculates the duration (Y) based on value (X)
     - the pinContracts (identified by a bytes32 hash) registered under the offer
     */
    struct Offer {
        uint256 capacity;
        Equation.Node[] equation; // equation that maps price to duration
        mapping(bytes32 => PinContract) pinContractRegistry;
    }

    /*
    PinContract represents:
    - the size of the file
    - date when the pinContract was initiated
    - (Wei) depositedkeccak256(abi.encodePacked(offerProvider, offerCounter[offerProvider]-1)))])
    - (Wei) withdrawn
    */
    struct PinContract {
        uint256 size;
        uint256 startDate;
        uint256 deposited;
        uint256 withdrawn;
    }

    // the offerRegistry maps an offerIdentifier (keccak256(offerProvider, offerCount)) to an offer
    mapping(bytes32 => Offer) offerRegistry;
    // how many offers the provider ever registered, only the most rec
    mapping(address => uint256) offerCounter;

    event OfferMade(address indexed offerProvider, bytes32 indexed offerIdentifier, uint256[] expressions, uint256 capacity);
    event OfferChanged(address indexed offerProvider, address indexed offerIdentifier, uint256 capacity);
    event ContractMade(address indexed offerProvider, bytes32 indexed offerIdentifier, uint256 size, uint256 startDate, uint256 deposited);
    /**
    * @notice makes an offer
    * @dev equation is initialized based on expressions. 
    * equation is read as if it is the *pre-order* traversal of the expression tree.
    * For instance, expression x^2 - 3 is encoded as: [5, 8, 1, 0, 2, 0, 3]
    *
    *                 5 (Opcode -)
    *                    /  \
    *                   /     \
    *                /          \
    *         8 (Opcode **)       \
    *             /   \             \
    *           /       \             \
    *         /           \             \
    *  1 (Opcode X)  0 (Opcode c)  0 (Opcode c)
    *                     |              |
    *                     |              |
    *                 2 (Value)     3 (Value)
    *
    */
    function makeOffer(uint256 _capacity, uint256[] memory expressions) public {
        require(_capacity != 0 && expressions[0] != 0); // offer must make sense
        bytes32 offerIdentifier = getOfferIdentifier(msg.sender, offerCounter[msg.sender]);
        Offer storage offer = offerRegistry[offerIdentifier];
        offer.capacity = _capacity;
        // update offerCount when we update the equation
        if(expressions.length != 0) {
            require(offerCounter[msg.sender] != 0);
            offer.equation.init(expressions);
            offerCounter[msg.sender] += 1;
        } 
        emit OfferMade(msg.sender, offerIdentifier, expressions, _capacity);
    }

    /**
    * @notice accepts an offer 
    */
    function makeContract(bytes32 offerIdentifier, address payable offerProvider, uint256 size, bytes32 pinContractIdentifier) public payable {
        PinContract storage pinContract =  offerRegistry[offerIdentifier].pinContractRegistry[pinContractIdentifier];
        require(offerIdentifier == getOfferIdentifier(offerProvider, offerCounter[offerProvider]-1)); // we can only take the latest offer
        // we accept a contract when we don't ever have accepted this offer before, or when we previously have accepted this offer, but it was expired in the meantime.
        // pinContract was active before
        if(pinContract.deposited != 0) {
            uint256 duration = calculateDuration(offerIdentifier, pinContract.deposited);
            require(pinContract.startDate + duration <= now); // pinContract must have expired
            // when the final payout was not yet done
            if(pinContract.deposited != pinContract.withdrawn) {
                offerProvider.transfer(pinContract.deposited - pinContract.withdrawn);
                offerRegistry[offerIdentifier].capacity.add(size); // release capacity
            }
            pinContract.withdrawn = 0;
        }
        offerRegistry[offerIdentifier].capacity.sub(size); // take capacity, revert if size > capacity
        pinContract.deposited = msg.value;
        pinContract.size = size;
        pinContract.startDate = now;
    }

    function prolongContract(bytes32 offerIdentifier, address offerProvider, bytes32 pinContractIdentifier) public payable {
        PinContract storage pinContract =  offerRegistry[offerIdentifier].pinContractRegistry[pinContractIdentifier];
        uint256 duration = calculateDuration(offerIdentifier, pinContract.deposited);
        require(pinContract.startDate + duration > now); // offer must not be expired yet
        require(offerIdentifier== getOfferIdentifier(offerProvider, offerCounter[offerProvider]-1)); // there must be no new offer registered
        require(offerRegistry[offerIdentifier].capacity.sub(pinContract.size) >= 0); // capacity must be still available
        pinContract.deposited += msg.value;
    }

    function requestPayout(bytes32 offerIdentifier, uint256 offerCount, bytes32 pinContractIdentifier, uint256 amount) public {
        require(offerIdentifier == getOfferIdentifier(msg.sender, offerCount)); // only offerProvider may do this
        PinContract storage pinContract =  offerRegistry[offerIdentifier].pinContractRegistry[pinContractIdentifier];
        // if expired, we can transfer the full amount
        if(pinContract.startDate + calculateDuration(offerIdentifier, pinContract.deposited) <= now ) {
            pinContract.deposited = 0;
            offerRegistry[offerIdentifier].capacity += pinContract.size;
            msg.sender.transfer(pinContract.deposited);
            return;
        } else {
            // the duration (based on amount) should have passed already
            require(calculateDuration(offerIdentifier, amount) <= now - pinContract.startDate);
            // we cannot withdraw more than is deposited (TODO: this condition can probably never be false)
            require(pinContract.withdrawn <= pinContract.deposited);
            pinContract.withdrawn += amount;
            msg.sender.transfer(amount);
        }
    }

    function cancelContract(bytes32 offerIdentifier, uint256 offerCount, bytes32 pinContractIdentifer, bytes memory reasons) public {
        require(offerIdentifier == getOfferIdentifier(msg.sender, offerCount)); // only offerProvider may do this
        // emit reason
    }    

    function calculateDuration(bytes32 offerIdentifier, uint256 price) public view returns(uint256) {
        return offerRegistry[offerIdentifier].equation.calculate(price);
    }

    // an offerIdentifier comprises the offerProvider and a count, to allow updating an offer, but keeping the same identity (offerProvider)
    function getOfferIdentifier(address offerProvider, uint256 offerCount) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(offerProvider, offerCount));
    }
}