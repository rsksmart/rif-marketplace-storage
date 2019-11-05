let PinningManager = artifacts.require("PinningManager");

module.exports = function(deployer) {
    deployer.deploy(PinningManager)
}