// let StorageManager = artifacts.require("StorageManager");

// module.exports = function(deployer) {
//     deployer.deploy(StorageManager)
// }
const { ZWeb3, Contracts, SimpleProject } = require('@openzeppelin/upgrades')

ZWeb3.initialize("http://localhost:8545")
// Load the contract.
const StorageManagerV0 = Contracts.getFromLocal('StorageManager')
// Instantiate a project.
StorageManagers = new SimpleProject('StorageManagers', { from: await ZWeb3.defaultAccount() })
// Create a proxy for the contract.
StorageManagers.createProxy(StorageManagerV0).then(proxy => myProxy = proxy)

// Make a change on the contract, and compile it.
// const MyContractUpgraded = Contracts.getFromLocal('MyContract')
// myProject.upgradeProxy(proxy, MyContractUpgraded)