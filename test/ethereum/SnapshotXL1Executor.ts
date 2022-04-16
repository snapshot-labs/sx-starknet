import { expect } from 'chai';
import hre, { ethers, network, waffle } from 'hardhat';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { executeContractCallWithSigners, buildContractCall, EIP712_TYPES } from './shared/utils';
import { AddressZero } from '@ethersproject/constants';

const [wallet_0, wallet_1, wallet_2, wallet_3, wallet_4] = waffle.provider.getWallets();

const tx1 = {
  to: wallet_1.address,
  value: 0,
  data: '0x11',
  operation: 0,
  nonce: 0,
};

const tx2 = {
  to: wallet_2.address,
  value: 0,
  data: '0x22',
  operation: 0,
  nonce: 0,
};

const tx3 = {
  to: wallet_3.address,
  value: 0,
  data: '0x33',
  operation: 0,
  nonce: 0,
};

async function baseSetup() {
  const GnosisSafeL2 = await hre.ethers.getContractFactory(
    '@gnosis.pm/safe-contracts/contracts/GnosisSafeL2.sol:GnosisSafeL2'
  );
  const FactoryContract = await hre.ethers.getContractFactory(
    '@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol:GnosisSafeProxyFactory'
  );
  const singleton = await GnosisSafeL2.deploy();
  const factory = await FactoryContract.deploy();

  const template = await factory.callStatic.createProxy(singleton.address, '0x');
  await factory.createProxy(singleton.address, '0x');

  const template2 = await factory.callStatic.createProxy(singleton.address, '0x');
  await factory.createProxy(singleton.address, '0x');

  const safe = GnosisSafeL2.attach(template);
  safe.setup([wallet_0.address], 1, AddressZero, '0x', AddressZero, AddressZero, 0, AddressZero);
  const safe2 = GnosisSafeL2.attach(template2);
  safe2.setup([wallet_0.address], 1, AddressZero, '0x', AddressZero, AddressZero, 0, AddressZero);

  const moduleFactoryContract = await ethers.getContractFactory('ModuleProxyFactory');
  const moduleFactory = await moduleFactoryContract.deploy();

  const SnapshotXContract = await ethers.getContractFactory('SnapshotXL1Executor');

  //deploying singleton master contract
  const masterSnapshotXModule = await SnapshotXContract.deploy(
    '0x0000000000000000000000000000000000000001',
    '0x0000000000000000000000000000000000000001',
    '0x0000000000000000000000000000000000000001',
    '0x0000000000000000000000000000000000000001',
    1,
    []
  );

  const encodedInitParams = ethers.utils.defaultAbiCoder.encode(
    ['address', 'address', 'address', 'address', 'uint256', 'uint256[]'],
    [
      safe.address,
      safe.address,
      safe.address,
      '0xB0aC056995C4904a9cc04A6Cc3a864A9E9A7d3a9',
      1234,
      [],
    ]
  );

  const initData = masterSnapshotXModule.interface.encodeFunctionData('setUp', [encodedInitParams]);

  const masterCopyAddress = masterSnapshotXModule.address.toLowerCase().replace(/^0x/, '');

  //This is the bytecode of the module proxy contract
  const byteCode =
    '0x602d8060093d393df3363d3d373d3d3d363d73' +
    masterCopyAddress +
    '5af43d82803e903d91602b57fd5bf3';

  const salt = ethers.utils.solidityKeccak256(
    ['bytes32', 'uint256'],
    [ethers.utils.solidityKeccak256(['bytes'], [initData]), '0x01']
  );

  const expectedAddress = ethers.utils.getCreate2Address(
    moduleFactory.address,
    salt,
    ethers.utils.keccak256(byteCode)
  );

  expect(await moduleFactory.deployModule(masterSnapshotXModule.address, initData, '0x01'))
    .to.emit(moduleFactory, 'ModuleProxyCreation')
    .withArgs(expectedAddress, masterSnapshotXModule.address);
  const SnapshotXModule = SnapshotXContract.attach(expectedAddress);

  const addCall = buildContractCall(
    safe,
    'addOwnerWithThreshold',
    [wallet_2.address, 1],
    await safe.nonce()
  );
  const addCall_1 = buildContractCall(
    safe,
    'addOwnerWithThreshold',
    [wallet_3.address, 1],
    await safe.nonce()
  );
  const addCall_2 = buildContractCall(
    safe,
    'addOwnerWithThreshold',
    [wallet_4.address, 1],
    await safe.nonce()
  );
  const txHash = await SnapshotXModule.getTransactionHash(
    addCall.to,
    addCall.value,
    addCall.data,
    addCall.operation
  );
  const txHash_1 = await SnapshotXModule.getTransactionHash(
    addCall_1.to,
    addCall_1.value,
    addCall_1.data,
    addCall_1.operation
  );
  const txHash_2 = await SnapshotXModule.getTransactionHash(
    addCall_2.to,
    addCall_2.value,
    addCall_2.data,
    addCall_2.operation
  );

  await executeContractCallWithSigners(
    safe,
    safe,
    'enableModule',
    [SnapshotXModule.address],
    [wallet_0]
  );

  return {
    SnapshotXModule: SnapshotXModule as any,
    safe: safe as any,
    safe2: safe2 as any,
    factory: factory as any,
    addCall: addCall as any,
    addCall_1: addCall_1 as any,
    addCall_2: addCall_2 as any,
    txHash: txHash as any,
    txHash_1: txHash_1 as any,
    txHash_2: txHash_2 as any,
  };
}

async function receiveProposalTest(SnapshotXModule: any) {
  const domain = {
    chainId: ethers.BigNumber.from(network.config.chainId),
    verifyingContract: SnapshotXModule.address,
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
  await SnapshotXModule.receiveProposalTest(callerAddress, executionHash, proposal_outcome, [
    txHash1,
    txHash2,
  ]);

  return {
    tx_hash1: txHash1 as any,
    tx_hash2: txHash2 as any,
  };
}

describe('Snapshot X L1 Proposal Executor:', () => {
  // can use the safe and a cancel proposal role
  describe('setUp', async () => {
    it('can initialize and set up the SnapshotX module', async () => {
      const { SnapshotXModule, safe } = await baseSetup();

      expect(await SnapshotXModule.avatar()).to.equal(safe.address);
      expect(await SnapshotXModule.owner()).to.equal(safe.address);
      expect(await SnapshotXModule.target()).to.equal(safe.address);
      expect(await SnapshotXModule.proposalIndex()).to.equal(0);
      expect(await SnapshotXModule.l2ExecutionRelayer()).to.equal(1234);
      expect(await SnapshotXModule.starknetCore()).to.equal(
        '0xB0aC056995C4904a9cc04A6Cc3a864A9E9A7d3a9'
      );
    });

    it('The safe can register Snapshot X module', async () => {
      const { SnapshotXModule, safe } = await baseSetup();
      expect(await safe.isModuleEnabled(SnapshotXModule.address)).to.equal(true);
    });
  });

  describe('Setters', async () => {
    it('The safe can change the address of the L2 decision executor contract', async () => {
      const { SnapshotXModule, safe } = await baseSetup();
      await expect(
        executeContractCallWithSigners(
          safe,
          SnapshotXModule,
          'changeL2ExecutionRelayer',
          [4567],
          [wallet_0]
        )
      )
        .to.emit(SnapshotXModule, 'ChangedL2ExecutionRelayer')
        .withArgs(4567);
    });
    it('Other accounts cannot change the address of the L2 decision executor contract', async () => {
      const { SnapshotXModule, safe } = await baseSetup();
      await expect(
        executeContractCallWithSigners(
          safe,
          SnapshotXModule,
          'changeL2ExecutionRelayer',
          [4567],
          [wallet_1]
        )
      ).to.be.revertedWith('GS026');
    });

    it('The safe can disable Snapshot X module', async () => {
      const { SnapshotXModule, safe } = await baseSetup();

      await expect(
        executeContractCallWithSigners(
          safe,
          safe,
          'disableModule',
          ['0x0000000000000000000000000000000000000001', SnapshotXModule.address],
          [wallet_0]
        )
      )
        .to.emit(safe, 'DisabledModule')
        .withArgs(SnapshotXModule.address);

      expect(await safe.isModuleEnabled(SnapshotXModule.address)).to.equal(false);
    });
  });

  describe('Getters', async () => {
    it('The module should return the number of transactions in a proposal', async () => {
      const { SnapshotXModule } = await baseSetup();
      await receiveProposalTest(SnapshotXModule);
      expect(await SnapshotXModule.getNumOfTxInProposal(0)).to.equal(2);
    });

    it('The module should return whether a transaction in a proposal has been executed', async () => {
      const { SnapshotXModule } = await baseSetup();
      await receiveProposalTest(SnapshotXModule);

      expect(await SnapshotXModule.isTxExecuted(0, 0)).to.equal(false);
      expect(await SnapshotXModule.isTxExecuted(0, 1)).to.equal(false);
      await SnapshotXModule.executeProposalTx(0, tx1.to, tx1.value, tx1.data, tx1.operation);
      expect(await SnapshotXModule.isTxExecuted(0, 0)).to.equal(true);
      expect(await SnapshotXModule.isTxExecuted(0, 1)).to.equal(false);
    });
  });

  describe('Transaction Hashes', async () => {
    it('should hash transactions correctly', async () => {
      const { SnapshotXModule } = await baseSetup();
      const domain = {
        chainId: ethers.BigNumber.from(network.config.chainId),
        verifyingContract: SnapshotXModule.address,
      };

      expect(
        await SnapshotXModule.getTransactionHash(tx1.to, tx1.value, tx1.data, tx1.operation)
      ).to.be.equals(_TypedDataEncoder.hash(domain, EIP712_TYPES, tx1));
    });
  });

  describe('Proposal Receival', async () => {
    it('The module can receive a proposal', async () => {
      const { SnapshotXModule } = await baseSetup();
      expect(await SnapshotXModule.getProposalState(0)).to.equal(0);
      const { tx_hash1, tx_hash2 } = await receiveProposalTest(SnapshotXModule);

      expect(await SnapshotXModule.proposalIndex()).to.equal(1);
      expect(await SnapshotXModule.getTxHash(0, 0)).to.equal(tx_hash1);
      expect(await SnapshotXModule.getTxHash(0, 1)).to.equal(tx_hash2);
      expect(await SnapshotXModule.getProposalState(0)).to.equal(1);
    });

    it('The module can receive multiple proposals', async () => {
      const { SnapshotXModule } = await baseSetup();
      expect(await SnapshotXModule.getProposalState(0)).to.equal(0);
      const { tx_hash1, tx_hash2 } = await receiveProposalTest(SnapshotXModule);

      expect(await SnapshotXModule.proposalIndex()).to.equal(1);
      expect(await SnapshotXModule.getTxHash(0, 0)).to.equal(tx_hash1);
      expect(await SnapshotXModule.getTxHash(0, 1)).to.equal(tx_hash2);
      expect(await SnapshotXModule.getProposalState(0)).to.equal(1);
    });
  });

  describe('Proposal Cancellation', async () => {
    it('The safe can cancel a proposal', async () => {
      const { SnapshotXModule, safe } = await baseSetup();
      await receiveProposalTest(SnapshotXModule);

      expect(
        await executeContractCallWithSigners(
          safe,
          SnapshotXModule,
          'cancelProposals',
          [[0]],
          [wallet_0]
        )
      )
        .to.emit(SnapshotXModule, 'ProposalCancelled')
        .withArgs(0);
      expect(await SnapshotXModule.getProposalState(0)).to.equal(4);
    });

    it('proposal cancel should revert with only owner', async () => {
      const { SnapshotXModule } = await baseSetup();
      await receiveProposalTest(SnapshotXModule);

      await expect(SnapshotXModule.cancelProposals([0])).to.be.revertedWith(
        'Ownable: caller is not the owner'
      );
      expect(await SnapshotXModule.getProposalState(0)).to.equal(1);
    });

    it('Cancellation should fail if all transactions in proposal have been executed', async () => {
      const { SnapshotXModule, safe } = await baseSetup();
      await receiveProposalTest(SnapshotXModule);

      await SnapshotXModule.executeProposalTxBatch(
        0,
        [tx1.to, tx2.to],
        [tx1.value, tx2.value],
        [tx1.data, tx2.data],
        [tx1.operation, tx1.operation]
      );

      expect(await SnapshotXModule.getProposalState(0)).to.equal(3);

      await expect(
        executeContractCallWithSigners(safe, SnapshotXModule, 'cancelProposals', [[0]], [wallet_0])
      ).to.be.reverted;

      expect(await SnapshotXModule.getProposalState(0)).to.equal(3);
    });
  });

  describe('Proposal Execution', async () => {
    it('The module can execute one transaction in a proposal', async () => {
      const { SnapshotXModule } = await baseSetup();
      const { tx_hash1 } = await receiveProposalTest(SnapshotXModule);

      await expect(SnapshotXModule.executeProposalTx(0, tx1.to, tx1.value, tx1.data, tx1.operation))
        .to.emit(SnapshotXModule, 'TransactionExecuted')
        .withArgs(0, tx_hash1);

      expect(await SnapshotXModule.getProposalState(0)).to.equal(2);
    });

    it('The module can execute all transactions in a proposal individually', async () => {
      const { SnapshotXModule } = await baseSetup();
      const { tx_hash1, tx_hash2 } = await receiveProposalTest(SnapshotXModule);

      await expect(SnapshotXModule.executeProposalTx(0, tx1.to, tx1.value, tx1.data, tx1.operation))
        .to.emit(SnapshotXModule, 'TransactionExecuted')
        .withArgs(0, tx_hash1);

      await expect(SnapshotXModule.executeProposalTx(0, tx2.to, tx2.value, tx2.data, tx2.operation))
        .to.emit(SnapshotXModule, 'TransactionExecuted')
        .withArgs(0, tx_hash2)
        .to.emit(SnapshotXModule, 'ProposalExecuted')
        .withArgs(0);

      expect(await SnapshotXModule.getProposalState(0)).to.equal(3);
    });

    it('The module can execute all transactions in a proposal via batch function', async () => {
      const { SnapshotXModule } = await baseSetup();
      await receiveProposalTest(SnapshotXModule);

      await expect(
        SnapshotXModule.executeProposalTxBatch(
          0,
          [tx1.to, tx2.to],
          [tx1.value, tx2.value],
          [tx1.data, tx2.data],
          [tx1.operation, tx1.operation]
        )
      )
        .to.emit(SnapshotXModule, 'ProposalExecuted')
        .withArgs(0);

      expect(await SnapshotXModule.getProposalState(0)).to.equal(3);
    });

    it('The module should revert if an incorrect transaction order was used', async () => {
      const { SnapshotXModule } = await baseSetup();
      await receiveProposalTest(SnapshotXModule);

      //attempting to execute tx2 before tx1
      await expect(
        SnapshotXModule.executeProposalTx(0, tx2.to, tx2.value, tx2.data, tx2.operation)
      ).to.be.revertedWith('Invalid transaction or invalid transaction order');

      expect(await SnapshotXModule.getProposalState(0)).to.equal(1);
    });

    it('The module should revert if a transaction was invalid', async () => {
      const { SnapshotXModule } = await baseSetup();
      await receiveProposalTest(SnapshotXModule);

      //attempting to execute tx3 (not in proposal) in place of tx1
      await expect(
        SnapshotXModule.executeProposalTx(0, tx3.to, tx3.value, tx3.data, tx3.operation)
      ).to.be.revertedWith('Invalid transaction or invalid transaction order');

      expect(await SnapshotXModule.getProposalState(0)).to.equal(1);
    });
  });
});
