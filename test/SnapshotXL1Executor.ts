import { expect } from 'chai';
import hre, { ethers, network, waffle } from 'hardhat';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { executeContractCallWithSigners, buildContractCall, EIP712_TYPES } from './shared/utils';
import { AddressZero } from '@ethersproject/constants';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';

//const [wallet_0, wallet_1, wallet_2, wallet_3, wallet_4] = await ethers.getSigners();

async function baseSetup(signers: { signer_0: SignerWithAddress; signer_1: SignerWithAddress }) {
  const tx1 = {
    to: signers.signer_0.address,
    value: 0,
    data: '0x11',
    operation: 0,
    nonce: 0,
  };

  const tx2 = {
    to: signers.signer_1.address,
    value: 0,
    data: '0x22',
    operation: 0,
    nonce: 0,
  };

  const tx3 = {
    to: signers.signer_0.address,
    value: 0,
    data: '0x33',
    operation: 0,
    nonce: 0,
  };

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
  safe.setup(
    [signers.signer_0.address],
    1,
    AddressZero,
    '0x',
    AddressZero,
    AddressZero,
    0,
    AddressZero
  );

  const moduleFactoryContract = await ethers.getContractFactory('ModuleProxyFactory');
  const moduleFactory = await moduleFactoryContract.deploy();

  const SnapshotXContract = await ethers.getContractFactory('SnapshotXL1Executor');

  //deploying singleton master contract
  const masterSnapshotXModule = await SnapshotXContract.deploy(
    '0x0000000000000000000000000000000000000001',
    '0x0000000000000000000000000000000000000001',
    '0x0000000000000000000000000000000000000001',
    '0x0000000000000000000000000000000000000001',
    1
  );

  const encodedInitParams = ethers.utils.defaultAbiCoder.encode(
    ['address', 'address', 'address', 'address', 'uint256'],
    [safe.address, safe.address, safe.address, '0xB0aC056995C4904a9cc04A6Cc3a864A9E9A7d3a9', 1234]
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

  await executeContractCallWithSigners(
    safe,
    safe,
    'enableModule',
    [SnapshotXModule.address],
    [signers.signer_0]
  );

  return {
    SnapshotXModule: SnapshotXModule as any,
    safe: safe as any,
    factory: factory as any,
    tx1: tx1 as any,
    tx2: tx2 as any,
    tx3: tx3 as any,
  };
}

async function receiveProposalTest(SnapshotXModule: any, tx1: any, tx2: any) {
  const domain = {
    chainId: ethers.BigNumber.from(network.config.chainId),
    verifyingContract: SnapshotXModule.address,
  };

  //2 transactions in proposal
  const tx_hash1 = _TypedDataEncoder.hash(domain, EIP712_TYPES, tx1);
  const tx_hash2 = _TypedDataEncoder.hash(domain, EIP712_TYPES, tx2);

  const abiCoder = new ethers.utils.AbiCoder();
  const execution_details = ethers.utils.keccak256(
    abiCoder.encode(['bytes32[]'], [[tx_hash1, tx_hash2]])
  );
  const has_passed = 1;
  await SnapshotXModule.receiveProposalTest(execution_details, has_passed, [tx_hash1, tx_hash2]);

  return {
    tx_hash1: tx_hash1 as any,
    tx_hash2: tx_hash2 as any,
  };
}

describe('Snapshot X L1 Proposal Executor:', () => {
  // can use the safe and a cancel proposal role
  describe('setUp', async () => {
    it('can initialize and set up the SnapshotX module', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, safe } = await baseSetup({ signer_0, signer_1 });

      expect(await SnapshotXModule.avatar()).to.equal(safe.address);
      expect(await SnapshotXModule.owner()).to.equal(safe.address);
      expect(await SnapshotXModule.target()).to.equal(safe.address);
      expect(await SnapshotXModule.proposalIndex()).to.equal(0);
      expect(await SnapshotXModule.decisionExecutorL2()).to.equal(1234);
      expect(await SnapshotXModule.starknetCore()).to.equal(
        '0xB0aC056995C4904a9cc04A6Cc3a864A9E9A7d3a9'
      );
    });

    it('The safe can register Snapshot X module', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, safe } = await baseSetup({ signer_0, signer_1 });
      expect(await safe.isModuleEnabled(SnapshotXModule.address)).to.equal(true);
    });
  });

  describe('Setters', async () => {
    it('The safe can change the address of the L2 decision executor contract', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, safe } = await baseSetup({ signer_0, signer_1 });
      await expect(
        executeContractCallWithSigners(
          safe,
          SnapshotXModule,
          'changeDecisionExecutorL2',
          [4567],
          [signer_0]
        )
      )
        .to.emit(SnapshotXModule, 'ChangedDecisionExecutorL2')
        .withArgs(4567);
    });
    it('Other accounts cannot change the address of the L2 decision executor contract', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, safe } = await baseSetup({ signer_0, signer_1 });
      await expect(
        executeContractCallWithSigners(
          safe,
          SnapshotXModule,
          'changeDecisionExecutorL2',
          [4567],
          [signer_1]
        )
      ).to.be.revertedWith('GS026');
    });

    it('The safe can disable Snapshot X module', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, safe } = await baseSetup({ signer_0, signer_1 });

      await expect(
        executeContractCallWithSigners(
          safe,
          safe,
          'disableModule',
          ['0x0000000000000000000000000000000000000001', SnapshotXModule.address],
          [signer_0]
        )
      )
        .to.emit(safe, 'DisabledModule')
        .withArgs(SnapshotXModule.address);

      expect(await safe.isModuleEnabled(SnapshotXModule.address)).to.equal(false);
    });
  });

  describe('Getters', async () => {
    it('The module should return the number of transactions in a proposal', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, tx1, tx2 } = await baseSetup({ signer_0, signer_1 });
      await receiveProposalTest(SnapshotXModule, tx1, tx2);
      expect(await SnapshotXModule.getNumOfTxInProposal(0)).to.equal(2);
    });

    it('The module should return whether a transaction in a proposal has been executed', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, tx1, tx2 } = await baseSetup({ signer_0, signer_1 });
      await receiveProposalTest(SnapshotXModule, tx1, tx2);

      expect(await SnapshotXModule.isTxExecuted(0, 0)).to.equal(false);
      expect(await SnapshotXModule.isTxExecuted(0, 1)).to.equal(false);
      await SnapshotXModule.executeProposalTx(0, tx1.to, tx1.value, tx1.data, tx1.operation);
      expect(await SnapshotXModule.isTxExecuted(0, 0)).to.equal(true);
      expect(await SnapshotXModule.isTxExecuted(0, 1)).to.equal(false);
    });
  });

  describe('Transaction Hashes', async () => {
    it('should hash transactions correctly', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, tx1, tx2 } = await baseSetup({ signer_0, signer_1 });
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
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, tx1, tx2 } = await baseSetup({ signer_0, signer_1 });
      expect(await SnapshotXModule.getProposalState(0)).to.equal(0);
      const { tx_hash1, tx_hash2 } = await receiveProposalTest(SnapshotXModule, tx1, tx2);

      expect(await SnapshotXModule.proposalIndex()).to.equal(1);
      expect(await SnapshotXModule.getTxHash(0, 0)).to.equal(tx_hash1);
      expect(await SnapshotXModule.getTxHash(0, 1)).to.equal(tx_hash2);
      expect(await SnapshotXModule.getProposalState(0)).to.equal(1);
    });

    it('The module can receive multiple proposals', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, tx1, tx2 } = await baseSetup({ signer_0, signer_1 });
      expect(await SnapshotXModule.getProposalState(0)).to.equal(0);
      const { tx_hash1, tx_hash2 } = await receiveProposalTest(SnapshotXModule, tx1, tx2);

      expect(await SnapshotXModule.proposalIndex()).to.equal(1);
      expect(await SnapshotXModule.getTxHash(0, 0)).to.equal(tx_hash1);
      expect(await SnapshotXModule.getTxHash(0, 1)).to.equal(tx_hash2);
      expect(await SnapshotXModule.getProposalState(0)).to.equal(1);
    });
  });

  describe('Proposal Cancellation', async () => {
    it('The safe can cancel a proposal', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, safe, tx1, tx2 } = await baseSetup({ signer_0, signer_1 });
      await receiveProposalTest(SnapshotXModule, tx1, tx2);

      expect(
        await executeContractCallWithSigners(
          safe,
          SnapshotXModule,
          'cancelProposals',
          [[0]],
          [signer_0]
        )
      )
        .to.emit(SnapshotXModule, 'ProposalCancelled')
        .withArgs(0);
      expect(await SnapshotXModule.getProposalState(0)).to.equal(4);
    });

    it('proposal cancel should revert with only owner', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, tx1, tx2 } = await baseSetup({ signer_0, signer_1 });
      await receiveProposalTest(SnapshotXModule, tx1, tx2);

      await expect(SnapshotXModule.cancelProposals([0])).to.be.revertedWith(
        'Ownable: caller is not the owner'
      );
      expect(await SnapshotXModule.getProposalState(0)).to.equal(1);
    });

    it('Cancellation should fail if all transactions in proposal have been executed', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, safe, tx1, tx2 } = await baseSetup({ signer_0, signer_1 });
      await receiveProposalTest(SnapshotXModule, tx1, tx2);

      await SnapshotXModule.executeProposalTxBatch(
        0,
        [tx1.to, tx2.to],
        [tx1.value, tx2.value],
        [tx1.data, tx2.data],
        [tx1.operation, tx1.operation]
      );

      expect(await SnapshotXModule.getProposalState(0)).to.equal(3);

      await expect(
        executeContractCallWithSigners(safe, SnapshotXModule, 'cancelProposals', [[0]], [signer_0])
      ).to.be.reverted;

      expect(await SnapshotXModule.getProposalState(0)).to.equal(3);
    });
  });

  describe('Proposal Execution', async () => {
    it('The module can execute one transaction in a proposal', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, tx1, tx2 } = await baseSetup({ signer_0, signer_1 });
      const { tx_hash1 } = await receiveProposalTest(SnapshotXModule, tx1, tx2);

      await expect(SnapshotXModule.executeProposalTx(0, tx1.to, tx1.value, tx1.data, tx1.operation))
        .to.emit(SnapshotXModule, 'TransactionExecuted')
        .withArgs(0, tx_hash1);

      expect(await SnapshotXModule.getProposalState(0)).to.equal(2);
    });

    it('The module can execute all transactions in a proposal individually', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, tx1, tx2 } = await baseSetup({ signer_0, signer_1 });
      const { tx_hash1, tx_hash2 } = await receiveProposalTest(SnapshotXModule, tx1, tx2);

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
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, tx1, tx2 } = await baseSetup({ signer_0, signer_1 });
      await receiveProposalTest(SnapshotXModule, tx1, tx2);

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
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, tx1, tx2 } = await baseSetup({ signer_0, signer_1 });
      await receiveProposalTest(SnapshotXModule, tx1, tx2);

      //attempting to execute tx2 before tx1
      await expect(
        SnapshotXModule.executeProposalTx(0, tx2.to, tx2.value, tx2.data, tx2.operation)
      ).to.be.revertedWith('Invalid transaction or invalid transaction order');

      expect(await SnapshotXModule.getProposalState(0)).to.equal(1);
    });

    it('The module should revert if a transaction was invalid', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { SnapshotXModule, tx1, tx2, tx3 } = await baseSetup({ signer_0, signer_1 });
      await receiveProposalTest(SnapshotXModule, tx1, tx2);

      //attempting to execute tx3 (not in proposal) in place of tx1
      await expect(
        SnapshotXModule.executeProposalTx(0, tx3.to, tx3.value, tx3.data, tx3.operation)
      ).to.be.revertedWith('Invalid transaction or invalid transaction order');

      expect(await SnapshotXModule.getProposalState(0)).to.equal(1);
    });
  });
});
