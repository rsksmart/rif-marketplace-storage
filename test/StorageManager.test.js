/* eslint-disable @typescript-eslint/no-var-requires,no-undef */
const {
  expectEvent,
  expectRevert,
  balance
} = require('@openzeppelin/test-helpers')
const { asciiToHex, padRight } = require('web3-utils')
const expect = require('chai').expect
const StorageManager = artifacts.require('TestStorageManager')

function getAgreementReference (receipt) {
  const newAgreementEvent = receipt.logs.find(e => e.event === 'NewAgreement')
  return newAgreementEvent.args.agreementReference
}

contract('StorageManager', ([Provider, Consumer, randomPerson]) => {
  let storageManager
  const cid = [asciiToHex('/ipfs/QmSomeHash')]

  beforeEach(async function () {
    storageManager = await StorageManager.new({ from: randomPerson })
    await storageManager.setTime(100)
  })

  async function expectCapacity (capacity) {
    expect((await storageManager.getOfferCapacity(Provider)).toNumber()).to.eql(capacity)
  }

  describe('setOffer', () => {
    it('should create new Offer for valid inputs', async () => {
      const msg = [padRight(asciiToHex('some string'), 64), padRight(asciiToHex('some other string'), 64)]
      const receipt = await storageManager.setOffer(1000, [10, 100], [10, 80], msg, { from: Provider })
      expectEvent(receipt, 'AvailableCapacitySet', {
        provider: Provider,
        capacity: '1000'
      })
      expectEvent(receipt, 'BillingPlanSet', {
        provider: Provider,
        period: '10',
        price: '10'
      })
      expectEvent(receipt, 'BillingPlanSet', {
        provider: Provider,
        period: '100',
        price: '80'
      })

      // TODO: Waiting for support of asserting arrays to be released for validation of emitted message.
      expectEvent(receipt, 'MessageEmitted')
    })

    it('should revert for no billing plan', async () => {
      await expectRevert(storageManager.setOffer(1000, [], [], [], { from: Provider }), 'StorageManager: Offer needs some billing plans')
    })

    it('should revert when billing plans array is not the same size as billing prices', async () => {
      await expectRevert(storageManager.setOffer(1000, [1], [1, 2], [], { from: Provider }), 'StorageManager: Billing plans array length has to equal to billing prices')
    })
  })

  describe('newAgreement', () => {
    it('should create new Agreement for valid inputs', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })

      const receipt = await storageManager.newAgreement(cid, Provider, 100, 10, [], { from: Consumer, value: 2000 })
      expectEvent(receipt, 'NewAgreement', {
        provider: Provider,
        agreementCreator: Consumer,
        size: '100',
        billingPeriod: '10',
        billingPrice: '10',
        availableFunds: '2000'
      })
    })

    it('should revert for non-existing Offer', async () => {
      await expectRevert(storageManager.newAgreement(cid, Provider, 100, 10, [], { from: Consumer, value: 2000 }),
        'StorageManager: Offer for this Provider doesn\'t exist')
    })

    it('should revert for no billing period or size', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })

      await expectRevert(storageManager.newAgreement(cid, Provider, 0, 10, [], { from: Consumer, value: 2000 }),
        'StorageManager: size has to be bigger then 0')
      await expectRevert(storageManager.newAgreement(cid, Provider, 100, 0, [], { from: Consumer, value: 2000 }),
        'StorageManager: billing period of 0 not allowed')
    })

    it('should revert when agreement already exists', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })
      await storageManager.newAgreement(cid, Provider, 100, 10, [], { from: Consumer, value: 2000 })

      await expectRevert(storageManager.newAgreement(cid, Provider, 100, 100, [], { from: Consumer, value: 2000 }),
        'StorageManager: Agreement already active')
    })

    it('should revert for non existing Billing plan', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })
      await expectRevert(storageManager.newAgreement(cid, Provider, 100, 20, [], { from: Consumer, value: 2000 }),
        'StorageManager: billing price doesn\'t exist for Offer')
    })

    it('should revert when not enough value is deposited', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })
      await expectRevert(storageManager.newAgreement(cid, Provider, 100, 10, [], { from: Consumer, value: 10 }),
        'StorageManager: funds deposited has to be for at least one billing period')
    })

    it('should recreate expired Agreement ', async () => {
      await storageManager.setOffer(1000, [1, 2], [10, 20], [], { from: Provider })
      const agreementReference = getAgreementReference(await storageManager.newAgreement(cid, Provider, 100, 1, [], {
        from: Consumer,
        value: 1500
      }))

      await storageManager.incrementTime(1)

      await storageManager.payoutFunds([agreementReference], { from: Provider })
      const receipt = await storageManager.newAgreement(cid, Provider, 100, 2, [], { from: Consumer, value: 2000 })
      expectEvent(receipt, 'NewAgreement', {
        provider: Provider,
        agreementCreator: Consumer,
        size: '100',
        billingPeriod: '2',
        billingPrice: '20',
        availableFunds: '2500'
      })
    })

    it('should payout, terminate and freeup capacity of Agreements specified by Consumer', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })

      // Agreement that uses whole capacity of the offer
      const agreementReference = getAgreementReference(await storageManager.newAgreement(cid, Provider, 900, 10, [], {
        from: randomPerson,
        value: 10000
      }))

      await expectCapacity(100)

      // Revert because there is not enough capacity
      await expectRevert(storageManager.newAgreement(cid, Provider, 200, 10, [], { from: Consumer, value: 2000 }),
        'StorageManager: Insufficient capacity')

      // Lets fast forward when the first Agreement run out of founds and hence is awaiting for termination
      await storageManager.incrementTime(15)

      const receipt = await storageManager.newAgreement(cid, Provider, 200, 10, [agreementReference], {
        from: Consumer,
        value: 2000
      })
      expectEvent(receipt, 'NewAgreement', {
        provider: Provider,
        agreementCreator: Consumer,
        size: '200',
        billingPeriod: '10',
        billingPrice: '10',
        availableFunds: '2000'
      })
      expectEvent(receipt, 'AgreementFundsPayout', {
        agreementReference,
        amount: '9000'
      })
      expectEvent(receipt, 'AgreementStopped', {
        agreementReference
      })

      await expectCapacity(800)
    })
  })

  describe('depositFunds', function () {
    it('should deposit funds for valid inputs', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })
      await storageManager.newAgreement(cid, Provider, 100, 10, [], { from: Consumer, value: 2000 })

      const receipt = await storageManager.depositFunds(cid, Provider, { from: Consumer, value: 100 })
      expectEvent(receipt, 'AgreementFundsDeposited', {
        amount: '100'
      })
    })

    it('should revert when offer does not exists', async () => {
      await expectRevert(storageManager.depositFunds(cid, Provider, { from: Consumer, value: 100 }),
        'StorageManager: Offer for this Provider doesn\'t exist')
    })

    it('should revert when agreement does not exists', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })

      await expectRevert(storageManager.depositFunds(cid, Provider, { from: Consumer, value: 100 }),
        'StorageManager: Agreement for this Offer doesn\'t exist')
    })

    it('should revert when billing plans does not exist anymore', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })
      await storageManager.newAgreement(cid, Provider, 100, 10, [], { from: Consumer, value: 2000 })
      await storageManager.setBillingPlans([10, 100], [0, 80], { from: Provider })

      await expectRevert(storageManager.depositFunds(cid, Provider, { from: Consumer, value: 100 }),
        'StorageManager: price not available anymore')
    })

    it('should revert when agreement is expired', async () => {
      await storageManager.setOffer(1000, [1, 100], [10, 80], [], { from: Provider })
      const agreementReference = getAgreementReference(await storageManager.newAgreement(cid, Provider, 100, 1, [], {
        from: Consumer,
        value: 1500
      }))
      await storageManager.incrementTime(1)

      await storageManager.payoutFunds([agreementReference], { from: Provider })
      await expectRevert(storageManager.depositFunds(cid, Provider, { from: Consumer, value: 100 }),
        'StorageManager: Agreement not active')
    })
  })

  describe('withdrawFunds', function () {
    it('should withdraw funds for valid inputs', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })
      await storageManager.newAgreement(cid, Provider, 100, 10, [], { from: Consumer, value: 2000 })

      const receipt = await storageManager.withdrawFunds(cid, Provider, 1000, { from: Consumer })
      expectEvent(receipt, 'AgreementFundsWithdrawn', {
        amount: '1000'
      })
    })

    it('should withdraw all available funds when zero is passed', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })
      await storageManager.newAgreement(cid, Provider, 100, 10, [], { from: Consumer, value: 2000 })

      const receipt = await storageManager.withdrawFunds(cid, Provider, 0, { from: Consumer })
      expectEvent(receipt, 'AgreementFundsWithdrawn', {
        amount: '1000'
      })
    })

    it('should revert when too big amount is requested to be withdrawn', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })
      await storageManager.newAgreement(cid, Provider, 100, 10, [], { from: Consumer, value: 3000 })

      // Should be 1 more ten limit. 100 (size) * 10 (price) = 1000 reserved and 2000 is available
      await expectRevert(storageManager.withdrawFunds(cid, Provider, 2001, { from: Consumer }),
        'StorageManager: Amount is too big')
    })

    it('should revert when somebody else then author of Agreement is trying to withdraw funds', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })
      await storageManager.newAgreement(cid, Provider, 100, 10, [], { from: Consumer, value: 3000 })

      await expectRevert(storageManager.withdrawFunds(cid, Provider, 1000, { from: randomPerson }),
        'StorageManager: Agreement for this Offer doesn\'t exist')
    })

    it('should revert when amount exceeds current period', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })
      await storageManager.newAgreement(cid, Provider, 100, 10, [], { from: Consumer, value: 2000 })

      await expectRevert(storageManager.withdrawFunds(cid, Provider, 1001, { from: Consumer }),
        'StorageManager: Amount is too big')
    })

    /**
     * The agreements has to block funds for all previous periods that were still not-payed out
     * to the Provider.
     */
    it('should revert when amount exceeds non-payed out periods', async () => {
      await storageManager.setOffer(1000, [1, 10], [10, 80], [], { from: Provider })
      await storageManager.newAgreement(cid, Provider, 100, 1, [], { from: Consumer, value: 5000 })
      await storageManager.incrementTime(1)

      await expectRevert(storageManager.withdrawFunds(cid, Provider, 3001, { from: Consumer }),
        'StorageManager: Amount is too big')
    })

    it('should withdraw all funds except reserved funds for past periods and current period', async () => {
      await storageManager.setOffer(1000, [1, 100], [10, 80], [], { from: Provider })
      await storageManager.newAgreement(cid, Provider, 100, 1, [], { from: Consumer, value: 5000 })
      await storageManager.incrementTime(1)

      const receipt = await storageManager.withdrawFunds(cid, Provider, 0, { from: Consumer })
      expectEvent(receipt, 'AgreementFundsWithdrawn', {
        amount: '3000'
      })
    })

    it('should revert because zero funds would be withdrawn as everything is reserved', async () => {
      await storageManager.setOffer(1000, [1, 100], [10, 80], [], { from: Provider })
      await storageManager.newAgreement(cid, Provider, 100, 1, [], { from: Consumer, value: 5000 })
      await storageManager.incrementTime(4)

      await expectRevert(storageManager.withdrawFunds(cid, Provider, 0, { from: Consumer }),
        'StorageManager: Nothing to withdraw')
    })

    it('should revert when offer does not exists', async () => {
      await expectRevert(storageManager.withdrawFunds(cid, Provider, 100, { from: Consumer }),
        'StorageManager: Offer for this Provider doesn\'t exist')
    })

    it('should revert when agreement does not exists', async () => {
      await storageManager.setOffer(1000, [10, 100], [10, 80], [], { from: Provider })

      await expectRevert(storageManager.withdrawFunds(cid, Provider, 100, { from: Consumer }),
        'StorageManager: Agreement for this Offer doesn\'t exist')
    })

    it('should withdraw all remaining funds when the agreement is expired', async () => {
      await storageManager.setOffer(1000, [1, 100], [10, 80], [], { from: Provider })
      const agreementReference = getAgreementReference(await storageManager.newAgreement(cid, Provider, 100, 1, [], {
        from: Consumer,
        value: 2500
      }))
      await storageManager.incrementTime(2)

      const payoutReceipt = await storageManager.payoutFunds([agreementReference], { from: Provider })
      expectEvent(payoutReceipt, 'AgreementFundsPayout', {
        agreementReference,
        amount: '2000'
      })
      expectEvent(payoutReceipt, 'AgreementStopped', {
        agreementReference
      })

      const withdrawReceipt = await storageManager.withdrawFunds(cid, Provider, 0, { from: Consumer })
      expectEvent(withdrawReceipt, 'AgreementFundsWithdrawn', {
        amount: '500'
      })
    })
  })

  describe('payoutFunds', function () {
    it('should payout funds for valid inputs', async () => {
      await storageManager.setOffer(1000, [1, 100], [10, 80], [], { from: Provider })
      const agreementReference = getAgreementReference(
        await storageManager.newAgreement(cid, Provider, 100, 1, [], { from: Consumer, value: 5000 })
      )
      await storageManager.incrementTime(2)

      const receipt = await storageManager.payoutFunds([agreementReference], { from: Provider })
      expectEvent(receipt, 'AgreementFundsPayout', {
        amount: '2000'
      })
    })

    it('should payout funds and stop agreement when run out of funds', async () => {
      await storageManager.setOffer(1000, [1, 100], [10, 80], [], { from: Provider })
      const agreementReference = getAgreementReference(
        await storageManager.newAgreement(cid, Provider, 100, 1, [], { from: Consumer, value: 2500 })
      )

      await expectCapacity(900)
      await storageManager.incrementTime(2)

      const receipt = await storageManager.payoutFunds([agreementReference], { from: Provider })
      expectEvent(receipt, 'AgreementFundsPayout', {
        agreementReference,
        amount: '2000'
      })
      expectEvent(receipt, 'AgreementStopped', {
        agreementReference
      })
      await expectCapacity(1000)
    })
  })
})
