/* eslint-disable @typescript-eslint/no-var-requires,no-undef */
const {
  expectEvent,
  expectRevert,
  balance,
  constants
} = require('@openzeppelin/test-helpers')
const { toBN, asciiToHex, padRight } = require('web3-utils')
const expect = require('chai').expect

const Staking = artifacts.require('Staking')
const StorageManager = artifacts.require('StorageManager')
const ERC20 = artifacts.require('MockERC20')

contract('Staking', ([staker, stakerFriend, randomPerson]) => {
  let token
  let storageManager
  let stakingNative
  let stakingToken

  beforeEach(async function () {
    storageManager = await StorageManager.new({ from: randomPerson })
    token = await ERC20.new('myToken', 'mT', randomPerson, 100000, { from: randomPerson })
    stakingNative = await Staking.new(storageManager.address, constants.ZERO_ADDRESS, { from: randomPerson })
    stakingToken = await Staking.new(storageManager.address, token.address, { from: randomPerson })

    // distribute tokens
    await token.transfer(staker, 10000, { from: randomPerson })
    await token.transfer(stakerFriend, 10000, { from: randomPerson })
  })

  describe('stakeNative', () => {
    it('should process a stake', async () => {
      const sender = staker
      const toStake = 5000
      // track balance
      const initialBalance = await balance.current(staker)
      // should start at 0
      expect((await stakingNative.totalStakedFor(sender)).toNumber()).to.eql(0)
      // stake
      const receipt = await stakingNative.stake(0, constants.ZERO_BYTES32, { from: sender, value: toStake, gasPrice: 0 })
      // should emit event
      expectEvent(receipt, 'Staked', {
        user: sender,
        amount: '5000',
        total: '5000',
        data: constants.ZERO_BYTES32
      })
      // should update staked value
      expect((await stakingNative.totalStakedFor(sender)).toNumber()).to.eql(toStake)
      // should update initial balance
      const nextBalance = await balance.current(staker)
      expect(initialBalance.sub(toBN(5000))).to.eql(nextBalance)
    })
  })

  describe('stakeToken', () => {
    it('should process a stake', async () => {
      const sender = staker
      const toStake = 5000
      // track balance
      const initialBalance = await token.balanceOf(staker)
      // should start at 0
      expect((await stakingToken.totalStakedFor(sender)).toNumber()).to.eql(0)
      // allow token
      await token.approve(stakingToken.address, toStake, { from: sender })
      // stake
      const receipt = await stakingToken.stake(toStake, constants.ZERO_BYTES32, { from: sender, gasPrice: 0 })
      // should emit event
      expectEvent(receipt, 'Staked', {
        user: sender,
        amount: '5000',
        total: '5000',
        data: constants.ZERO_BYTES32
      })
      // should update staked value
      expect((await stakingToken.totalStakedFor(sender)).toNumber()).to.eql(toStake)
      // should update initial balance
      const nextBalance = await token.balanceOf(staker)
      expect(initialBalance.sub(toBN(toStake))).to.eql(nextBalance.sub(toBN(0)))
    })
  })

  describe('stakeForNative', () => {
    it('should process a stake', async () => {
      const stakeFor = staker
      const sender = staker
      const toStake = 5000
      // track balance
      const initialBalance = await balance.current(staker)
      // should start at 0
      expect((await stakingNative.totalStakedFor(stakeFor)).toNumber()).to.eql(0)
      // stake
      const receipt = await stakingNative.stakeFor(0, stakeFor, constants.ZERO_BYTES32, { from: sender, value: toStake, gasPrice: 0 })
      // should emit event
      expectEvent(receipt, 'Staked', {
        user: sender,
        amount: '5000',
        total: '5000',
        data: constants.ZERO_BYTES32
      })
      // should update staked value
      expect((await stakingNative.totalStakedFor(stakeFor)).toNumber()).to.eql(toStake)
      // should update initial balance
      const nextBalance = await balance.current(staker)
      expect(initialBalance.sub(toBN(5000))).to.eql(nextBalance)
    })
  })

  describe('stakeForToken', () => {
    it('should process a stake', async () => {
      const stakeFor = staker
      const sender = staker
      const toStake = 5000
      // track balance
      const initialBalance = await token.balanceOf(staker)
      // should start at 0
      expect((await stakingToken.totalStakedFor(stakeFor)).toNumber()).to.eql(0)
      // allow token
      await token.approve(stakingToken.address, toStake, { from: sender })
      // stake
      const receipt = await stakingToken.stakeFor(toStake, stakeFor, constants.ZERO_BYTES32, { from: sender, gasPrice: 0 })
      // should emit event
      expectEvent(receipt, 'Staked', {
        user: sender,
        amount: '5000',
        total: '5000',
        data: constants.ZERO_BYTES32
      })
      // should update staked value
      expect((await stakingToken.totalStakedFor(stakeFor)).toNumber()).to.eql(toStake)
      // should update initial balance
      const nextBalance = await token.balanceOf(staker)
      expect(initialBalance.sub(toBN(5000))).to.eql(nextBalance.sub(toBN(0)))
    })
  })

  describe('unstakeNative', () => {
    it('should not unstake when storage offer active', async () => {
      const toStake = 5000
      // set StorageOffer by staker
      await storageManager.setOffer(1000, [10, 100], [10, 80], [padRight(asciiToHex('testMessage'))], { from: staker })
      // newAgreement by randomPerson
      await storageManager.newAgreement([asciiToHex('/ipfs/QmSomeHash')], staker, 100, 10, [], { from: randomPerson, value: 2000 })
      // stake
      await stakingNative.stake(0, constants.ZERO_BYTES32, { from: staker, value: toStake, gasPrice: 0 })
      // attempt to unstake
      await expectRevert(stakingNative.unstake(toStake, constants.ZERO_BYTES32, { from: staker }), 'Staking: must have no utilized capacity in StorageManager')
    })

    it('should process an unstake when no active offer', async () => {
      const toStake = 5000
      const initialBalance = await balance.current(staker)
      await stakingNative.stake(0, constants.ZERO_BYTES32, { from: staker, value: toStake, gasPrice: 0 })
      const receipt = await stakingNative.unstake(toStake, constants.ZERO_BYTES32, { from: staker, gasPrice: 0 })
      const nextBalance = await balance.current(staker)
      // should emit event
      expectEvent(receipt, 'Unstaked', {
        user: staker,
        amount: '5000',
        total: '0',
        data: constants.ZERO_BYTES32
      })
      // final balance equal to initial balance
      expect(initialBalance).to.eql(nextBalance)
    })
  })

  describe('unstakeToken', () => {
    it('should not unstake when storage offer active', async () => {
      const toStake = 5000
      // set StorageOffer by staker
      await storageManager.setOffer(1000, [10, 100], [10, 80], [padRight(asciiToHex('testMessage'))], { from: staker })
      // newAgreement by randomPerson
      await storageManager.newAgreement([asciiToHex('/ipfs/QmSomeHash')], staker, 100, 10, [], { from: randomPerson, value: 2000 })
      // approve
      await token.approve(stakingToken.address, toStake, { from: staker })
      // stake
      await stakingToken.stake(toStake, constants.ZERO_BYTES32, { from: staker, gasPrice: 0 })
      // attempt to unstake
      await expectRevert(stakingToken.unstake(toStake, constants.ZERO_BYTES32, { from: staker }), 'Staking: must have no utilized capacity in StorageManager')
    })

    it('should process an unstake when no active offer', async () => {
      const toStake = 5000
      const initialBalance = await token.balanceOf(staker)
      // approve
      await token.approve(stakingToken.address, toStake, { from: staker })
      await stakingToken.stake(toStake, constants.ZERO_BYTES32, { from: staker, gasPrice: 0 })
      const receipt = await stakingToken.unstake(toStake, constants.ZERO_BYTES32, { from: staker, gasPrice: 0 })
      const nextBalance = await token.balanceOf(staker)
      // should emit event
      expectEvent(receipt, 'Unstaked', {
        user: staker,
        amount: '5000',
        total: '0',
        data: constants.ZERO_BYTES32
      })
      // final balance equal to initial balance
      expect(initialBalance).to.eql(nextBalance)
    })
  })

  describe('totalStakedNative', () => {
    it('should return total staked when staked 0', async () => {
      expect(toBN(await stakingNative.totalStaked())).to.be.bignumber.equal(toBN(0))
    })
    it('should return total staked when staked', async () => {
      const toStake = 5000
      await stakingNative.stake(0, constants.ZERO_BYTES32, { from: staker, value: toStake, gasPrice: 0 })
      expect(toBN(await stakingNative.totalStaked())).to.be.bignumber.equal(toBN(toStake))
    })
    it('should return total staked when staked and unstaked', async () => {
      const toStake = 5000
      const toUnstake = 2500
      // stake
      await stakingNative.stake(0, constants.ZERO_BYTES32, { from: staker, value: toStake, gasPrice: 0 })
      // unstake
      await stakingNative.unstake(toUnstake, constants.ZERO_BYTES32, { from: staker, gasPrice: 0 })
      expect(toBN(await stakingNative.totalStaked())).to.be.bignumber.equal(toBN(toStake - toUnstake))
    })
  })

  describe('totalStakedToken', () => {
    it('should return total staked when staked 0', async () => {
      expect(toBN(await stakingToken.totalStaked())).to.be.bignumber.equal(toBN(0))
    })
    it('should return total staked when staked', async () => {
      const toStake = 5000
      // approve
      await token.approve(stakingToken.address, toStake, { from: staker })
      // stake
      await stakingToken.stake(toStake, constants.ZERO_BYTES32, { from: staker, gasPrice: 0 })
      expect(toBN(await stakingToken.totalStaked())).to.be.bignumber.equal(toBN(toStake))
    })
    it('should return total staked when staked and unstaked', async () => {
      const toStake = 5000
      const toUnstake = 2500
      // approve
      await token.approve(stakingToken.address, toStake, { from: staker })
      // stake
      await stakingToken.stake(toStake, constants.ZERO_BYTES32, { from: staker, gasPrice: 0 })
      // unstake
      await stakingToken.unstake(toUnstake, constants.ZERO_BYTES32, { from: staker, gasPrice: 0 })
      expect(toBN(await stakingToken.totalStaked())).to.be.bignumber.equal(toBN(toStake - toUnstake))
    })
  })

  describe('totalStakedForNative', () => {
    it('should return total staked when staked 0', async () => {
      expect(toBN(await stakingNative.totalStakedFor(staker))).to.be.bignumber.equal(toBN(0))
    })
    it('should return total staked when staked', async () => {
      const toStake = 5000
      await stakingNative.stake(0, constants.ZERO_BYTES32, { from: staker, value: toStake, gasPrice: 0 })
      expect(toBN(await stakingNative.totalStakedFor(staker))).to.be.bignumber.equal(toBN(toStake))
    })
    it('should return total staked when staked and unstaked', async () => {
      const toStake = 5000
      const toUnstake = 2500
      // stake
      await stakingNative.stake(0, constants.ZERO_BYTES32, { from: staker, value: toStake, gasPrice: 0 })
      // unstake
      await stakingNative.unstake(toUnstake, constants.ZERO_BYTES32, { from: staker, gasPrice: 0 })
      expect(toBN(await stakingNative.totalStakedFor(staker))).to.be.bignumber.equal(toBN(toStake - toUnstake))
    })
  })

  describe('totalStakedForToken', () => {
    it('should return total staked when staked 0', async () => {
      expect(toBN(await stakingToken.totalStakedFor(staker))).to.be.bignumber.equal(toBN(0))
    })
    it('should return total staked when staked', async () => {
      const toStake = 5000
      // approve
      await token.approve(stakingToken.address, toStake, { from: staker })
      // stake
      await stakingToken.stake(toStake, constants.ZERO_BYTES32, { from: staker, gasPrice: 0 })
      expect(toBN(await stakingToken.totalStakedFor(staker))).to.be.bignumber.equal(toBN(toStake))
    })
    it('should return total staked when staked and unstaked', async () => {
      const toStake = 5000
      const toUnstake = 2500
      // approve
      await token.approve(stakingToken.address, toStake, { from: staker })
      // stake
      await stakingToken.stake(toStake, constants.ZERO_BYTES32, { from: staker, gasPrice: 0 })
      // unstake
      await stakingToken.unstake(toUnstake, constants.ZERO_BYTES32, { from: staker, gasPrice: 0 })
      expect(toBN(await stakingToken.totalStakedFor(staker))).to.be.bignumber.equal(toBN(toStake - toUnstake))
    })
  })
})
