const { expect } = require('chai');
const {
    BN,
    balance,
    time,
    expectEvent,
    expectRevert
  } = require("openzeppelin-test-helpers");

const PinningManager = artifacts.require('PinningManager');

contract('PinningManager', function([PinningProvider, user, randomPerson]) {
  beforeEach(async function() {
      this.pinningManager = await PinningManager.new({from: randomPerson})
  })

  describe(`Create pinning offer`, function() {
    context('one price/duration point', function() {
      
    })
    context('two price/duration points', function() {

    })    
    context('zero price/duration points', function() {
      // revert
    })
    context('more than 256 price/duration points', function() {
      // revert
    })

  })

  describe('Update pinning offer (capacity)', function() {
    
  })

  describe('Update pinning offer (price)', function() {

  })

  describe('Accept pinning offer', function() {
    context('non-existant', function() {

    })
    context('expired', function() {
      context('final payout done', function() {

      })
      context('final payout not done', function() {
        // do final payment
      })
    })
    context('non-expired', function() {
      // revert
    })
  })

  describe('Prolong contract', function() {
    context('non-expired', function() {

    })
    context('non-existant', function() {
      // revert
    })
    context('expired', function() {
      // revert
    })
    context('offer expired', function() {
      // revert
    })
  })

  describe('Request payment', function() {
    context('expired', function() {

    })
    context('not expired', function() {
      context('linear function', function() {
        context('half of price duration', function(){

        })
        context('at price duration', function() {

        })
        context('two times price duration', function() {
          
        })
      })
    })
  })
})