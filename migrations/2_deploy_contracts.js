let StorageManager = artifacts.require("StorageManager");
let StorageManagerToken = artifacts.require("StorageManagerToken");

let tokenAddress = "0x0000000000000000000000000000000000000000"

module.exports = function(deployer) {
    deployer.deploy(StorageManager)
    deployer.deploy(StorageManagerToken, tokenAddress)
}
