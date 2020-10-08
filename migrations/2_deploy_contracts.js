const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const StorageManager = artifacts.require("StorageManager");
const Staking = artifacts.require("Staking");

module.exports = async function(deployer) {
   const storageManager = await deployProxy(StorageManager, [], { deployer, unsafeAllowCustomTypes: true });
   await deployer.deploy(Staking, storageManager.address); 
}
