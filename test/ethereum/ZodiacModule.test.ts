import { expect } from 'chai';
import hre, { ethers, network } from 'hardhat';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { executeContractCallWithSigners, EIP712_TYPES } from '../shared/safeUtils';
import { Contract } from 'ethers';
import { safeWithZodiacSetup } from '../shared/setup';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

describe('Snapshot X L1 Proposal Executor:', () => {
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
  let wallet_4: SignerWithAddress;

  beforeEach(async () => {
    [wallet_0, wallet_1, wallet_2, wallet_3, wallet_4] = await hre.ethers.getSigners(); //waffle.provider.getWallets();
    ({ zodiacModule, safe, safeSigner } = await safeWithZodiacSetup());

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
    it('can initialize and set up the SnapshotX module', async () => {
      expect(await zodiacModule.avatar()).to.equal(safe.address);
      expect(await zodiacModule.owner()).to.equal(safe.address);
      expect(await zodiacModule.target()).to.equal(safe.address);
      expect(await zodiacModule.proposalIndex()).to.equal(0);
    });

    it('The safe can register Snapshot X module', async () => {
      expect(await safe.isModuleEnabled(zodiacModule.address)).to.equal(true);
    });
  });

  describe('Setters', async () => {
    it('The safe can change the address of the L2 decision executor contract', async () => {
      await expect(
        executeContractCallWithSigners(
          safe,
          zodiacModule,
          'changeL2ExecutionRelayer',
          [4567],
          [wallet_0]
        )
      )
        .to.emit(zodiacModule, 'ChangedL2ExecutionRelayer')
        .withArgs(4567);
    });
    it('Other accounts cannot change the address of the L2 decision executor contract', async () => {
      await expect(
        executeContractCallWithSigners(
          safe,
          zodiacModule,
          'changeL2ExecutionRelayer',
          [4567],
          [wallet_1]
        )
      ).to.be.revertedWith('GS026');
    });

    it('The safe can disable Snapshot X module', async () => {
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
  });

  describe('Getters', async () => {
    it('The module should return the number of transactions in a proposal', async () => {
      await receiveProposalTest(zodiacModule, tx1, tx2);
      expect(await zodiacModule.getNumOfTxInProposal(0)).to.equal(2);
    });

    it('The module should return whether a transaction in a proposal has been executed', async () => {
      await receiveProposalTest(zodiacModule, tx1, tx2);

      expect(await zodiacModule.isTxExecuted(0, 0)).to.equal(false);
      expect(await zodiacModule.isTxExecuted(0, 1)).to.equal(false);
      await zodiacModule.executeProposalTx(0, tx1.to, tx1.value, tx1.data, tx1.operation);
      expect(await zodiacModule.isTxExecuted(0, 0)).to.equal(true);
      expect(await zodiacModule.isTxExecuted(0, 1)).to.equal(false);
    });
  });

  describe('Transaction Hashes', async () => {
    it('should hash transactions correctly', async () => {
      const domain = {
        chainId: ethers.BigNumber.from(network.config.chainId),
        verifyingContract: zodiacModule.address,
      };

      expect(
        await zodiacModule.getTransactionHash(tx1.to, tx1.value, tx1.data, tx1.operation)
      ).to.be.equals(_TypedDataEncoder.hash(domain, EIP712_TYPES, tx1));
    });
  });

  describe('Proposal Receival', async () => {
    it('The module can receive a proposal', async () => {
      expect(await zodiacModule.getProposalState(0)).to.equal(0);
      const { tx_hash1, tx_hash2 } = await receiveProposalTest(zodiacModule, tx1, tx2);

      expect(await zodiacModule.proposalIndex()).to.equal(1);
      expect(await zodiacModule.getTxHash(0, 0)).to.equal(tx_hash1);
      expect(await zodiacModule.getTxHash(0, 1)).to.equal(tx_hash2);
      expect(await zodiacModule.getProposalState(0)).to.equal(1);
    });

    it('The module can receive multiple proposals', async () => {
      const { zodiacModule } = await safeWithZodiacSetup();
      expect(await zodiacModule.getProposalState(0)).to.equal(0);
      const { tx_hash1, tx_hash2 } = await receiveProposalTest(zodiacModule, tx1, tx2);

      expect(await zodiacModule.proposalIndex()).to.equal(1);
      expect(await zodiacModule.getTxHash(0, 0)).to.equal(tx_hash1);
      expect(await zodiacModule.getTxHash(0, 1)).to.equal(tx_hash2);
      expect(await zodiacModule.getProposalState(0)).to.equal(1);
    });
  });

  describe('Proposal Cancellation', async () => {
    it('The safe can cancel a proposal', async () => {
      await receiveProposalTest(zodiacModule, tx1, tx2);

      expect(
        await executeContractCallWithSigners(
          safe,
          zodiacModule,
          'cancelProposals',
          [[0]],
          [wallet_0]
        )
      )
        .to.emit(zodiacModule, 'ProposalCancelled')
        .withArgs(0);
      expect(await zodiacModule.getProposalState(0)).to.equal(4);
    });

    it('proposal cancel should revert with only owner', async () => {
      await receiveProposalTest(zodiacModule, tx1, tx2);

      await expect(zodiacModule.cancelProposals([0])).to.be.revertedWith(
        'Ownable: caller is not the owner'
      );
      expect(await zodiacModule.getProposalState(0)).to.equal(1);
    });

    it('Cancellation should fail if all transactions in proposal have been executed', async () => {
      await receiveProposalTest(zodiacModule, tx1, tx2);

      await zodiacModule.executeProposalTxBatch(
        0,
        [tx1.to, tx2.to],
        [tx1.value, tx2.value],
        [tx1.data, tx2.data],
        [tx1.operation, tx1.operation]
      );

      expect(await zodiacModule.getProposalState(0)).to.equal(3);

      await expect(
        executeContractCallWithSigners(safe, zodiacModule, 'cancelProposals', [[0]], [wallet_0])
      ).to.be.reverted;

      expect(await zodiacModule.getProposalState(0)).to.equal(3);
    });
  });

  describe('Proposal Execution', async () => {
    it('The module can execute one transaction in a proposal', async () => {
      const { tx_hash1 } = await receiveProposalTest(zodiacModule, tx1, tx2);

      await expect(zodiacModule.executeProposalTx(0, tx1.to, tx1.value, tx1.data, tx1.operation))
        .to.emit(zodiacModule, 'TransactionExecuted')
        .withArgs(0, tx_hash1);

      expect(await zodiacModule.getProposalState(0)).to.equal(2);
    });

    it('The module can execute all transactions in a proposal individually', async () => {
      const { tx_hash1, tx_hash2 } = await receiveProposalTest(zodiacModule, tx1, tx2);

      await expect(zodiacModule.executeProposalTx(0, tx1.to, tx1.value, tx1.data, tx1.operation))
        .to.emit(zodiacModule, 'TransactionExecuted')
        .withArgs(0, tx_hash1);

      await expect(zodiacModule.executeProposalTx(0, tx2.to, tx2.value, tx2.data, tx2.operation))
        .to.emit(zodiacModule, 'TransactionExecuted')
        .withArgs(0, tx_hash2)
        .to.emit(zodiacModule, 'ProposalExecuted')
        .withArgs(0);

      expect(await zodiacModule.getProposalState(0)).to.equal(3);
    });

    it('The module can execute all transactions in a proposal via batch function', async () => {
      await receiveProposalTest(zodiacModule, tx1, tx2);

      await expect(
        zodiacModule.executeProposalTxBatch(
          0,
          [tx1.to, tx2.to],
          [tx1.value, tx2.value],
          [tx1.data, tx2.data],
          [tx1.operation, tx1.operation]
        )
      )
        .to.emit(zodiacModule, 'ProposalExecuted')
        .withArgs(0);

      expect(await zodiacModule.getProposalState(0)).to.equal(3);
    });

    it('The module should revert if an incorrect transaction order was used', async () => {
      await receiveProposalTest(zodiacModule, tx1, tx2);

      //attempting to execute tx2 before tx1
      await expect(
        zodiacModule.executeProposalTx(0, tx2.to, tx2.value, tx2.data, tx2.operation)
      ).to.be.revertedWith('Invalid transaction or invalid transaction order');

      expect(await zodiacModule.getProposalState(0)).to.equal(1);
    });

    it('The module should revert if a transaction was invalid', async () => {
      await receiveProposalTest(zodiacModule, tx1, tx2);

      //attempting to execute tx3 (not in proposal) in place of tx1
      await expect(
        zodiacModule.executeProposalTx(0, tx3.to, tx3.value, tx3.data, tx3.operation)
      ).to.be.revertedWith('Invalid transaction or invalid transaction order');

      expect(await zodiacModule.getProposalState(0)).to.equal(1);
    });
  });
});

async function receiveProposalTest(zodiacModule: Contract, tx1: any, tx2: any) {
  const domain = {
    chainId: ethers.BigNumber.from(network.config.chainId),
    verifyingContract: zodiacModule.address,
  };

  //2 transactions in proposal
  const txHash1 = _TypedDataEncoder.hash(domain, EIP712_TYPES, tx1);
  const txHash2 = _TypedDataEncoder.hash(domain, EIP712_TYPES, tx2);

  const abiCoder = new ethers.utils.AbiCoder();
  const executionHash = ethers.utils.keccak256(
    abiCoder.encode(['bytes32[]'], [[txHash1, txHash2]])
  );

  // vitalik.eth
  const callerAddress = '0xd8da6bf26964af9d7eed9e03e53415d37aa96045';

  const proposal_outcome = 1;
  await zodiacModule.receiveProposalTest(callerAddress, executionHash, proposal_outcome, [
    txHash1,
    txHash2,
  ]);

  return {
    tx_hash1: txHash1 as any,
    tx_hash2: txHash2 as any,
  };
}
