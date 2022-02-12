import { expect } from 'chai';
import hre, { starknet, ethers, network, waffle } from 'hardhat';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { executeContractCallWithSigners, buildContractCall, EIP712_TYPES } from './shared/utils';
import { AddressZero } from '@ethersproject/constants';

const [wallet_0, wallet_1, wallet_2, wallet_3, wallet_4] = waffle.provider.getWallets();

const starknetCore = '0x0000000000000000000000000000000000001234';
const votingAuthL1 = '0x0000000000000000000000000000000000005678';

const voteA = {
  votingContract: 1,
  proposalID: 2,
  choice: 3,
};

const voteInvalidChoice = {
  votingContract: 1,
  proposalID: 2,
  choice: 5,
};

const proposalA = {
  votingContract: 1,
  executionHash: 2,
  metadataHash: 3,
  domain: 4,
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

  const safe = GnosisSafeL2.attach(template);
  safe.setup(
    [wallet_0.address, wallet_1.address, wallet_2.address],
    2,
    AddressZero,
    '0x',
    AddressZero,
    AddressZero,
    0,
    AddressZero
  );

  const L1VotingContract = await ethers.getContractFactory('SnapshotXL1Voting');

  const L1AuthFactory = await starknet.getContractFactory('L1AuthMock');

  const L1Auth = await L1AuthFactory.deploy();
//   console.log('Deployed at', L1Auth.address);
//   console.log('str: ', votingAuthL1)
  const L1Vote = await L1VotingContract.deploy(starknetCore, ethers.utils.toUtf8String(L1Auth.address));
  console.log('Deployed at', L1Vote.address);
  
  return {
    L1Vote: L1Vote as any,
    safe: safe as any,
    factory: factory as any,
  };
}

describe('Snapshot X L1 Voting Contract:', () => {
  describe('Set up', async () => {
    it('can initialize and set up the contract', async () => {
      const { L1Vote, safe } = await baseSetup();
      expect(await L1Vote.starknetCore()).to.equal(starknetCore);
      expect(await L1Vote.votingAuthL1()).to.equal(votingAuthL1);
    });
  });

  describe('Vote', async () => {
    it('can vote submit a vote from an EOA', async () => {
      const { L1Vote } = await baseSetup();
      await expect(
        L1Vote.voteOnL1(voteA.votingContract, voteA.proposalID, voteA.choice, {
          from: wallet_0.address,
        })
      )
        .to.emit(L1Vote, 'L1VoteSubmitted')
        .withArgs(voteA.votingContract, voteA.proposalID, voteA.choice, wallet_0.address);
    });

    it('can vote submit a vote from a safe', async () => {
      const { L1Vote, safe } = await baseSetup();
      expect(
        await executeContractCallWithSigners(
          safe,
          L1Vote,
          'voteOnL1',
          [voteA.votingContract, voteA.proposalID, voteA.choice],
          [wallet_0, wallet_1]
        )
      )
        .to.emit(L1Vote, 'L1VoteSubmitted')
        .withArgs(voteA.votingContract, voteA.proposalID, voteA.choice, safe.address);
    });

    it('should revert if an invalid vote is submitted', async () => {
      const { L1Vote, safe } = await baseSetup();
      await expect(
        L1Vote.voteOnL1(
          voteInvalidChoice.votingContract,
          voteInvalidChoice.proposalID,
          voteInvalidChoice.choice,
          {
            from: wallet_0.address,
          }
        )
      ).to.be.revertedWith('Invalid choice');
    });
  });

  describe('Propose', async () => {
    it('can submit a proposal from an EOA', async () => {
      const { L1Vote } = await baseSetup();
      await expect(
        L1Vote.proposeOnL1(
          proposalA.votingContract,
          proposalA.executionHash,
          proposalA.metadataHash,
          proposalA.domain,
          {
            from: wallet_0.address,
          }
        )
      )
        .to.emit(L1Vote, 'L1ProposalSubmitted')
        .withArgs(
          proposalA.votingContract,
          proposalA.executionHash,
          proposalA.metadataHash,
          proposalA.domain,
          wallet_0.address
        );
    });

    it('can submit a proposal from a safe', async () => {
      const { L1Vote, safe } = await baseSetup();
      expect(
        await executeContractCallWithSigners(
          safe,
          L1Vote,
          'proposeOnL1',
          [
            proposalA.votingContract,
            proposalA.executionHash,
            proposalA.metadataHash,
            proposalA.domain,
          ],
          [wallet_0, wallet_1]
        )
      )
        .to.emit(L1Vote, 'L1ProposalSubmitted')
        .withArgs(
          proposalA.votingContract,
          proposalA.executionHash,
          proposalA.metadataHash,
          proposalA.domain,
          safe.address
        );
    });
  });
});
