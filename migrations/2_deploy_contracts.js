let StorageManager = artifacts.require("StorageManager");

module.exports = function(deployer) {
    deployer.deploy(StorageManager)
}
