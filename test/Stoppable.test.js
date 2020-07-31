const { accounts, contract } = require('@openzeppelin/test-environment');

const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const { expect } = require('chai');

const StoppableMock = contract.fromArtifact('StoppableMock');

describe('Stoppable', function () {
  const [ stopper ] = accounts;

  beforeEach(async function () {
    this.stoppable = await StoppableMock.new();
  });

  context('when stopped', function () {
    beforeEach(async function () {
      expect(await this.stoppable.stopped()).to.equal(false);
    });

    it('can perform normal process in non-stop', async function () {
      expect(await this.stoppable.count()).to.be.bignumber.equal('0');

      await this.stoppable.normalProcess();
      expect(await this.stoppable.count()).to.be.bignumber.equal('1');
    });

    it('cannot take drastic measure in non-stop', async function () {
      await expectRevert(this.stoppable.drasticMeasure(),
        'Stoppable: not stopped'
      );
      expect(await this.stoppable.drasticMeasureTaken()).to.equal(false);
    });

    context('when stopped', function () {
      beforeEach(async function () {
        ({ logs: this.logs } = await this.stoppable.stop({ from: stopper }));
      });

      it('emits a Paused event', function () {
        expectEvent.inLogs(this.logs, 'Stopped', { account: stopper });
      });

      it('cannot perform normal process in stop', async function () {
        await expectRevert(this.stoppable.normalProcess(), 'Stoppable: stopped');
      });

      it('can take a drastic measure in stop', async function () {
        await this.stoppable.drasticMeasure();
        expect(await this.stoppable.drasticMeasureTaken()).to.equal(true);
      });

      it('reverts when re-stopping', async function () {
        await expectRevert(this.stoppable.stop(), 'Stoppable: stopped');
      });
    });
  });
});