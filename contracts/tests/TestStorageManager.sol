// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "../StorageManager.sol";

contract TestStorageManager is StorageManager {
    uint256 time;

    function _time() internal view override returns (uint256) {
        return time;
    }

    function incrementTime(uint256 increment) external {
        time = time + increment;
    }

    function setTime(uint256 newTime) external {
        time = newTime;
    }

    function getOfferUtilizedCapacity(address provider) public view returns (uint256) {
        return offerRegistry[provider].utilizedCapacity;
    }
}
