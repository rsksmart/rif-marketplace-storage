// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "../StorageManager.sol";

contract TestStorageManager is StorageManager {
    uint time;

    function _time() internal view override returns (uint) {
        return time;
    }

    function incrementTime(uint increment) external {
        time = time + increment;
    }

    function setTime(uint newTime) external {
        time = newTime;
    }

    function getOfferUtilizedCapacity(address provider) public view returns (uint) {
        return offerRegistry[provider].utilizedCapacity;
    }
}
