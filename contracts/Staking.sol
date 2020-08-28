pragma solidity 0.6.2;

import "./StorageManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract Staking {

    using SafeMath for uint256;

    StorageManager storageManager;

    mapping(address => uint256) internal amountStaked;
    uint256 internal _totalStaked;
    address internal _token;

    event Staked(address indexed user, uint256 amount, uint256 total, bytes data);
    event Unstaked(address indexed user, uint256 amount, uint256 total, bytes data);

    constructor(address _storageManager, address stakingToken) public {
        storageManager = StorageManager(_storageManager);
        _token = stakingToken;
    }

    function stake(uint256 amount, bytes memory data) public payable {
        stakeFor(amount, msg.sender, data);
    }

    function stakeFor(uint256 amount, address user, bytes memory data) public payable {
        // disregard passed-in amount
        if(contractUsesNativeToken()) {
            amount = msg.value;
        } else {
            require(ERC20(token).transferFrom(msg.sender, address(this), amount), "Staking: could not transfer tokens");
        }
        amountStaked[user] = amountStaked[user].add(amount);
        _totalStaked = _totalStaked.add(amount);
        emit Staked(msg.sender, amount, amountStaked[user], data);
    }

    function unstake(uint256 amount, bytes memory data) public {
        // only allow unstake if there is no utilized capacity
        require(storageManager.hasUtilizedCapacity(msg.sender));
        amountStaked[msg.sender] = amountStaked[msg.sender].sub(amount);
        _totalStaked = _totalStaked.sub(amount);
        if(contractUsesNativeToken()) {
            (bool success,) = msg.sender.call.value(amount)("");
            require(success, "Transfer failed.");
        } else {
            ERC20(_token).transfer(msg.sender, amount);
        }

        emit Unstaked(msg.sender, amount, amountStaked[msg.sender], data);
    }

    function totalStaked() public view returns (uint256) {
        return _totalStaked;
    }

    function totalStakedFor(address addr) public view returns (uint256) {
        return amountStaked[addr];
    }

    function contractUsesNativeToken() public view returns (bool) {
        return _token == address(0);
    }

    function supportsHistory() public pure returns (bool) {
        return false;
    }

}