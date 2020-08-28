pragma solidity 0.6.2;

import "./StorageManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title staking
/// @author see ERC900 proposal
/// @author Rinke Hendriksen <rinke@iovlabs.org>
/// @notice implements the ERC900 interface, with some small modifications. The contract also handles native tokens.
contract Staking {

    using SafeMath for uint256;

    StorageManager storageManager;
    // amount of token staked per address
    mapping(address => uint256) internal amountStaked;
    // total amount of token staked per address
    uint256 internal _totalStaked;
    // the ERC20 token of the contract. By convention, address(0) is the native currency
    // multicurrency is achieved by deploying multiple contract instances
    address internal _token;

    event Staked(address indexed user, uint256 amount, uint256 total, bytes data);
    event Unstaked(address indexed user, uint256 amount, uint256 total, bytes data);

    /**
    @notice constructor of the contract
    @param _storageManager the storageManager which uses this staking contract
    @param stakingToken the address of the token of this contract. By convention, address(0) is the native currency
    */
    constructor(address _storageManager, address stakingToken) public {
        storageManager = StorageManager(_storageManager);
        _token = stakingToken;
    }

    /**
    @notice stake the token via this function.
    @dev note that when you stake a non-native token, the caller must have given approval to the contract to transact tokens
    if the caller is a contract, it must implement the functionality to call unstake
    @param amount the amount you want to stake. Can be left blank when you are staking the native currency
    @param data should be disregarded for the current deployment
    */
    function stake(uint256 amount, bytes memory data) public payable {
        stakeFor(amount, msg.sender, data);
    }

    /**
    @notice stake tokens for somebody else via this function
    @dev note that when you stake a non-native token, the caller must have given approval to the contract to transact tokens
    if you are staking for a contract, the contract must be able to call unstake
    @param amount the amount you want to stake. Can be left blank when you are staking the native currency
    @param user the user for whom you are staking
    @param data should be disregarded for the current deployment
     */
    function stakeFor(uint256 amount, address user, bytes memory data) public payable {
        // disregard passed-in amount
        if(contractUsesNativeToken()) {
            amount = msg.value;
        } else {
            require(ERC20(_token).transferFrom(msg.sender, address(this), amount), "Staking: could not transfer tokens");
        }
        amountStaked[user] = amountStaked[user].add(amount);
        _totalStaked = _totalStaked.add(amount);
        emit Staked(msg.sender, amount, amountStaked[user], data);
    }

    /**
    @notice unstake tokens which where previously staked via this function. Only possible when you don't have any active storage agreements
    @param amount the total amount of tokens to unstake
    @param data should be disregarded for the current deployment
     */
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

    /**
    @notice returns the total amount staked for this contract
     */
    function totalStaked() public view returns (uint256) {
        return _totalStaked;
    }

    /**
    @notice returns the amount staked for the user
     */
    function totalStakedFor(address user) public view returns (uint256) {
        return amountStaked[user];
    }

    /**
    @notice contract does not support history functions (lastStakedFor, totalStakedForAt, totalStakedAt)
     */
    function supportsHistory() public pure returns (bool) {
        return false;
    }

    /**
    @notice if the contract uses the native token or not
     */
    function contractUsesNativeToken() public view returns (bool) {
        return _token == address(0);
    }
}