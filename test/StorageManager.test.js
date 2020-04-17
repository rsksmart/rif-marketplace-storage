/* eslint-disable */
const { expect } = require('chai');
const {
  BN,
  balance,
  time,
  expectEvent,
  expectRevert,
} = require('@openzeppelin/test-helpers');

const StorageManager = artifacts.require('StorageManager');

contract('StorageManager', ([PinningProvider, user, randomPerson]) => {
  beforeEach(async function () {
    this.storageManager = await StorageManager.new({ from: randomPerson });
  });

  describe('Create pinning offer', () => {
    context('one price/duration point', () => {});
    context('two price/duration points', () => {});
    context('zero price/duration points', () => {
      // revert
    });
    context('more than 256 price/duration points', () => {
      // revert
    });
  });

  describe('Update pinning offer (capacity)', () => {});

  describe('Update pinning offer (price)', () => {});

  describe('Accept pinning offer', () => {
    context('non-existant', () => {});
    context('expired', () => {
      context('final payout done', () => {});
      context('final payout not done', () => {
        // do final payment
      });
    });
    context('non-expired', () => {
      // revert
    });
  });

  describe('Prolong contract', () => {
    context('non-expired', () => {});
    context('non-existant', () => {
      // revert
    });
    context('expired', () => {
      // revert
    });
    context('offer expired', () => {
      // revert
    });
  });

  describe('Request payment', () => {
    context('expired', () => {});
    context('not expired', () => {
      context('linear function', () => {
        context('half of price duration', () => {});
        context('at price duration', () => {});
        context('two times price duration', () => {});
      });
    });
  });
});
