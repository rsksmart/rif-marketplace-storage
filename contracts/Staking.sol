pragma solidity 0.6.2;

import "./StorageManager.sol";

contract Staking {

    using SafeMath for uint256;

    StorageManager storageManager;

    mapping(address => uint256) internal amountStaked;
    uint256 internal _totalStaked;

    event Staked(address indexed user, uint256 amount, uint256 total, bytes data);
    event Unstaked(address indexed user, uint256 amount, uint256 total, bytes data);

    constructor(address _storageManager) public {
        storageManager = StorageManager(_storageManager);
    }

    function stake(bytes memory data) public payable {
        stakeFor(msg.sender, data);
    }

    function stakeFor(address user, bytes memory data) public payable {
        amountStaked[user] = amountStaked[user].add(msg.value);
        _totalStaked = _totalStaked.add(msg.value);
        emit Staked(msg.sender, msg.value, amountStaked[user], data);
    }

    function unstake(uint256 amount, bytes memory data) public {
        // only allow unstake if there is no utilized capacity
        require(storageManager.hasUtilizedCapacity(msg.sender));
        amountStaked[msg.sender] = amountStaked[msg.sender].sub(amount);
        _totalStaked = _totalStaked.sub(amount);
        emit Unstaked(msg.sender, amount, amountStaked[msg.sender], data);
    }

    function totalStaked() public view returns (uint256) {
        return _totalStaked;
    }

    function totalStakedFor(address addr) public view returns (uint256) {
        return amountStaked[addr];
    }

}