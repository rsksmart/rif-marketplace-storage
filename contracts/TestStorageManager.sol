pragma solidity 0.6.2;

import "./StorageManager.sol";

contract TestStorageManager is StorageManager {
    uint time;

    function _time() internal view override returns (uint) {
        return time;
    }

    function incrementTime(uint increment) public {
        time = time + increment;
    }

    function setTime(uint newTime) public {
        time = newTime;
    }

    function getOfferUtilizedCapacity(address provider) public view returns (uint) {
        return offerRegistry[provider].utilizedCapacity;
    }
}
