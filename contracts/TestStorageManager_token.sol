pragma solidity 0.6.2;

import "./StorageManager_token.sol";

contract TestStorageManagerToken is StorageManagerToken {
    uint time;

    constructor(address token) StorageManagerToken(token) public { }

    function _time() internal view override returns (uint) {
        if(time == 0){
            return now;
        }

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

contract TestToken is ERC20PresetMinterPauser {

    constructor(string memory name, string memory symbol) public ERC20PresetMinterPauser(name, symbol) { }

}
