const {
    expectEvent,
    expectRevert,
    balance,
    constants
  } = require('@openzeppelin/test-helpers')
const { toBN } = require('web3-utils')
const expect = require('chai').expect
const Staking = artifacts.require('Staking')
const StorageManager = artifacts.require('StorageManager')
const ERC20 = artifacts.require('MockERC20')

contract('Staking', ([staker, stakerFriend, randomPerson]) => {
    beforeEach(async function () {
        token = await ERC20.new(100000, { from: randomPerson });
        storageManager = await StorageManager.new({ from: randomPerson })
        stakingNative = await Staking.new(storageManager.address, constants.ZERO_ADDRESS, { from: randomPerson })
        stakingToken = await Staking.new(storageManager.address, token.address, {from: randomPerson })

        // distribute tokens
        token.transfer(staker, 10000, { from: randomPerson })
        token.transfer(stakerFriend, 10000, { from: randomPerson })
    })

    describe('stakeNative', () => {
      it('should process a stake', async () => {
        const sender = staker;
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
        const sender = staker;
        const toStake = 5000
        // track balance
        const initialBalance = await token.balanceOf(staker)
        // should start at 0
        expect((await stakingToken.totalStakedFor(sender)).toNumber()).to.eql(0)
        // allow token
        await token.approve(stakingToken.address, toStake, {from: sender})
        // stake
        const receipt = await stakingToken.stake(toStake, constants.ZERO_BYTES32, { from: sender,  gasPrice: 0 })
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
        const stakeFor = staker;
        const sender = staker;
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
        const stakeFor = staker;
        const sender = staker;
        const toStake = 5000
        // track balance
        const initialBalance = await token.balanceOf(staker)
        // should start at 0
        expect((await stakingToken.totalStakedFor(stakeFor)).toNumber()).to.eql(0)
        // allow token
        await token.approve(stakingToken.address, toStake, {from: sender})
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

      })

      it('should process an unstake when no active offer', async () => {

      })
    })

    describe('totalStaked', () => {

    })

    describe('totalStakedFor', () => {

    })
})