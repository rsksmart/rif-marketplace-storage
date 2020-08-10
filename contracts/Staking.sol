pragma solidity 0.6.2;

import "./vendor/SafeMath.sol";

contract Staking {

    using SafeMath for uint256;

    mapping(address => uint256) internal amountStaked;

    event Staked(address indexed user, uint256 amount, uint256 total, bytes data);
    event Unstaked(address indexed user, uint256 amount, uint256 total, bytes data);

    function stake(uint256 amount, bytes memory data) public payable {
        stakeFor(msg.sender, amount, data);
    }

    function stakeFor(address user, uint256 amount, bytes memory data) public payable {
        amountStaked[user] = amountStaked[user].add(msg.value);
        emit Staked(msg.sender, amount, amountStaked[user], data);
    }

    function unstake(uint256 amount, bytes memory data) public {
        amountStaked[msg.sender] = amountStaked[msg.sender].sub(amount);
        emit Unstaked(msg.sender, amount, amountStaked[msg.sender], data);
    }

    function totalStaked() public view returns (uint256) {
        return totalStakedFor(msg.sender);
    }

    function totalStakedFor(address addr) public view returns (uint256) {
        return amountStaked[addr];
    }

}