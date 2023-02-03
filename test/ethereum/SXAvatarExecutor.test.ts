import { expect } from 'chai';
import hre, { ethers, network } from 'hardhat';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { executeContractCallWithSigners, EIP712_TYPES } from '../shared/safeUtils';
import { Contract } from 'ethers';
import { safeWithZodiacSetup2 } from '../shared/setup';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

// Proposal States
const NOT_RECEIVED = 0;
const EXECUTING = 1;
const EXECUTED = 2;
const CANCELLED = 3;

describe('Snapshot X Avatar Executor:', () => {
  let zodiacModule: Contract;
  let safe: Contract;
  let safeSigner: SignerWithAddress;
  let tx1: any;
  let tx2: any;
  let tx3: any;
  let wallet_0: SignerWithAddress;
  let wallet_1: SignerWithAddress;
  let wallet_2: SignerWithAddress;
  let wallet_3: SignerWithAddress;

  beforeEach(async () => {
    [wallet_0, wallet_1, wallet_2, wallet_3] = await hre.ethers.getSigners(); //waffle.provider.getWallets();
    ({ zodiacModule, safe, safeSigner } = await safeWithZodiacSetup2());

    tx1 = {
      to: wallet_1.address,
      value: 0,
      data: '0x11',
      operation: 0,
      nonce: 0,
    };
    tx2 = {
      to: wallet_2.address,
      value: 0,
      data: '0x22',
      operation: 0,
      nonce: 0,
    };
    tx3 = {
      to: wallet_3.address,
      value: 0,
      data: '0x33',
      operation: 0,
      nonce: 0,
    };
  });

  describe('setUp', async () => {
    it('can initialize and set up the Snapshot X module', async () => {
      expect(await zodiacModule.owner()).to.equal(safe.address);
      expect(await zodiacModule.target()).to.equal(safe.address);
      expect(await zodiacModule.executionRelayer()).to.equal(1);
        expect(await zodiacModule.isSpaceEnabled(1)).to.equal(true);
    });

    it('The avatar can register the Snapshot X module', async () => {
      expect(await safe.isModuleEnabled(zodiacModule.address)).to.equal(true);
    });
  });

  describe('Setters', async () => {
    it('The owner can change the address of the L2 decision executor contract', async () => {
      await expect(
        executeContractCallWithSigners(
          safe,
          zodiacModule,
          'setExecutionRelayer',
          [4567],
          [wallet_0]
        )
      )
        .to.emit(zodiacModule, 'ExecutionRelayerSet')
        .withArgs(4567);
    });
    it('Other accounts cannot change the address of the L2 decision executor contract', async () => {
      await expect(
        executeContractCallWithSigners(
          safe,
          zodiacModule,
          'setExecutionRelayer',
          [4567],
          [wallet_1]
        )
      ).to.be.revertedWith('GS026');
    });

    it('The avatar can disable the Snapshot X module', async () => {
      await expect(
        executeContractCallWithSigners(
          safe,
          safe,
          'disableModule',
          ['0x0000000000000000000000000000000000000001', zodiacModule.address],
          [wallet_0]
        )
      )
        .to.emit(safe, 'DisabledModule')
        .withArgs(zodiacModule.address);

      expect(await safe.isModuleEnabled(zodiacModule.address)).to.equal(false);
    });

    it('can add spaces to the whitelist', async () => {
      expect(await zodiacModule.isSpaceEnabled(1234)).to.equal(false);
      await executeContractCallWithSigners(
        safe,
        zodiacModule,
        'enableSpace',
        [1234],
        [safeSigner]
      );
      expect(await zodiacModule.isSpaceEnabled(1234)).to.equal(true);
    });

    it('can remove spaces from the whitelist', async () => {
        expect(await zodiacModule.isSpaceEnabled(1)).to.equal(true);
        await executeContractCallWithSigners(
            safe,
            zodiacModule,
            'disableSpace',
            [1],
            [safeSigner]
        );
        expect(await zodiacModule.isSpaceEnabled(1234)).to.equal(false);
    });
  });
});

