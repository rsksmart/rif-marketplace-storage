const {
    expectEvent,
    expectRevert,
    balance,
    constants
  } = require('@openzeppelin/test-helpers')
const { toBN } = require('web3-utils')
const expect = require('chai').expect
const Staking = artifacts.require('Staking')

contract('Staking', ([staker, stakerFriend, randomPerson]) => {
    let staking

    beforeEach(async function () {
        staking = await Staking.new({ from: randomPerson })
    })

    describe('stake', () => {
      it('should process a stake', async () => {
        const sender = staker;
        const toStake = 5000
        // track balance
        const initialBalance = await balance.current(staker)
        // should start at 0
        expect((await staking.totalStakedFor(sender)).toNumber()).to.eql(0)
        // stake
        const receipt = await staking.stake(constants.ZERO_BYTES32, { from: sender, value: toStake, gasPrice: 0 })
        // should emit event
        expectEvent(receipt, 'Staked', {
          user: sender,
          amount: '5000',
          total: '5000', 
          data: constants.ZERO_BYTES32
        })
        // should update staked value
        expect((await staking.totalStakedFor(sender)).toNumber()).to.eql(toStake)
        // should update initial balance
        const nextBalance = await balance.current(staker)
        expect(initialBalance.sub(toBN(5000))).to.eql(nextBalance)
      })     
    })

    describe('stakeFor', () => {
      it('should process a stake', async () => {
        const stakeFor = staker;
        const sender = staker;
        const toStake = 5000
        // track balance
        const initialBalance = await balance.current(staker)
        // should start at 0
        expect((await staking.totalStakedFor(stakeFor)).toNumber()).to.eql(0)
        // stake
        const receipt = await staking.stakeFor(stakeFor, constants.ZERO_BYTES32, { from: sender, value: toStake, gasPrice: 0 })
        // should emit event
        expectEvent(receipt, 'Staked', {
            user: sender,
            amount: '5000',
            total: '5000', 
            data: constants.ZERO_BYTES32
        })
        // should update staked value
        expect((await staking.totalStakedFor(stakeFor)).toNumber()).to.eql(toStake)
        // should update initial balance
        const nextBalance = await balance.current(staker)
        expect(initialBalance.sub(toBN(5000))).to.eql(nextBalance)
      })     
    })

    describe('unstake', () => {

    })

    describe('totalStaked', () => {

    })

    describe('totalStakedFor', () => {

    })
})