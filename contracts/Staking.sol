// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./StorageManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title staking
/// @author see ERC900 proposal
/// @author Rinke Hendriksen <rinke@iovlabs.org>
/// @notice implements the ERC900 interface, with some small modifications. The contract also handles native tokens.
contract Staking is Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    StorageManager public storageManager;
    // amount of tokens per token staked per address [account -> (tokenAddress -> amount)]
    mapping(address => mapping(address => uint256)) internal _amountStaked;
    // total amount staked per token
    mapping(address => uint256) internal _totalStaked;
    // the ERC20 token of the contract. By convention, address(0) is the native currency
    // multicurrency is achieved by deploying multiple contract instances
    // maps the tokenAddresses which can be used with this contract. By convention, address(0) is the native token.
    mapping(address => bool) public isWhitelistedToken;

    event Staked(address indexed user, uint256 amount, uint256 total, address token, bytes data);
    event Unstaked(address indexed user, uint256 amount, uint256 total, address token, bytes data);

    /**
    @notice constructor of the contract
    @param _storageManager the storageManager which uses this staking contract
    */
    constructor(address _storageManager) public {
        storageManager = StorageManager(_storageManager);
    }

    /**
    @notice set Storage Manager contract
    @param _storageContract the storageManager which uses this staking contract
    */
    function setStorageManager(address _storageContract) public onlyOwner {
        storageManager = StorageManager(_storageContract);
    }

    /**
    @notice whitelist a token or remove the token from whitelist
    @param token the token from whom you want to set the whitelisted
    @param isWhiteListed whether you want to whitelist the token or put it from the whitelist.
    */
    function setWhitelistedTokens (address token, bool isWhiteListed) public onlyOwner {
        isWhitelistedToken[token] = isWhiteListed;
    }

    /**
    @notice stake the token via this function.
    @dev note that when you stake a non-native token, the caller must have given approval to the contract to transact tokens
    if the caller is a contract, it must implement the functionality to call unstake
    @param amount the amount you want to stake. Can be left blank when you are staking the native currency
    @param token Token address
    @param data should be disregarded for the current deployment
    */
    function stake(uint256 amount, address token, bytes memory data) public payable {
        stakeFor(amount, msg.sender, token, data);
    }

    /**
    @notice stake tokens for somebody else via this function
    @dev note that when you stake a non-native token, the caller must have given approval to the contract to transact tokens
    if you are staking for a contract, the contract must be able to call unstake
    @param amount the amount you want to stake. Can be left blank when you are staking the native currency
    @param user the user for whom you are staking
    @param tokenAddress Token address
    @param data should be disregarded for the current deployment
     */
    function stakeFor(uint256 amount, address user, address tokenAddress, bytes memory data) public payable {
        require(isInWhiteList(tokenAddress), "Staking: not possible to interact with this token");
        // disregard passed-in amount
        if(_isNativeToken(tokenAddress)) {
            amount = msg.value;
            tokenAddress = address(0);
        } else {
            IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        }
        _amountStaked[user][tokenAddress] = _amountStaked[user][tokenAddress].add(amount);
        _totalStaked[tokenAddress] = _totalStaked[tokenAddress].add(amount);
        emit Staked(user, amount, _amountStaked[user][tokenAddress], tokenAddress, data);
    }

    /**
    @notice unstake tokens which where previously staked via this function. Only possible when you don't have any active storage agreements
    @dev
     - if sender does not have nothing staked, the transaction will be reverted with "substraction overflow" error
    @param amount the total amount of tokens to unstake
    @param tokenAddress Token address
    @param data should be disregarded for the current deployment
     */
    function unstake(uint256 amount, address tokenAddress, bytes memory data) public {
        require(isInWhiteList(tokenAddress), "Staking: not possible to interact with this token");
        // only allow unstake if there is no utilized capacity
        require(!storageManager.hasUtilizedCapacity(msg.sender), "Staking: must have no utilized capacity in StorageManager");
        if(_isNativeToken(tokenAddress)) {
            (bool success,) = msg.sender.call{value: amount}("");
            require(success, "Transfer failed.");
        } else {
            IERC20(tokenAddress).safeTransfer(msg.sender, amount);
        }
        _amountStaked[msg.sender][tokenAddress] = _amountStaked[msg.sender][tokenAddress].sub(amount);
        _totalStaked[tokenAddress] = _totalStaked[tokenAddress].sub(amount);
        emit Unstaked(msg.sender, amount, _amountStaked[msg.sender][tokenAddress], tokenAddress, data);
    }

    /**
    @notice return true if token whitelisted
     */
    function isInWhiteList (address token) public view returns (bool) {
        return isWhitelistedToken[token];
    }

    /**
    @notice returns the amount staked for the specific token
    */
    function totalStaked (address token) public view returns (uint256) {
        return _totalStaked[token];
    }

    /**
    @notice returns the amount staked for the specific user and token
     */
    function totalStakedFor(address user, address token) public view returns (uint256) {
        return _amountStaked[user][token];
    }

    /**
    @notice contract does not support history functions (lastStakedFor, totalStakedForAt, totalStakedAt)
     */
    function supportsHistory() public pure returns (bool) {
        return false;
    }

    /**
    @notice if use a native token
     */
    function _isNativeToken(address token) private pure returns (bool) {
        return token == address(0);
    }
}
