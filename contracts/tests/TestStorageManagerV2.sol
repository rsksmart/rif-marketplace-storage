pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;
import "../StorageManager.sol";

contract TestStorageManagerV2 is StorageManager {
    function getVersion() public pure returns (string memory) {
        return "V2";
    }
}