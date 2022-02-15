import { expect } from 'chai';
import hre, { starknet, ethers } from 'hardhat';
import { executeContractCallWithSigners } from './shared/utils';
import { AddressZero } from '@ethersproject/constants';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';

const starknetCore = '0xde29d060D45901Fb19ED6C6e959EB22d8626708e';

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

async function baseSetup(signers: { signer_0: SignerWithAddress; signer_1: SignerWithAddress }) {
  const GnosisSafeL2 = await hre.ethers.getContractFactory(
    '@gnosis.pm/safe-contracts/contracts/GnosisSafeL2.sol:GnosisSafeL2'
  );
  const FactoryContract = await hre.ethers.getContractFactory(
    '@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol:GnosisSafeProxyFactory'
  );

  const singleton = await GnosisSafeL2.deploy();
  const factory = await FactoryContract.deploy();
  const template = await factory.callStatic.createProxy(singleton.address, '0x');
  let tx = await factory.createProxy(singleton.address, '0x');
  await tx.wait();
  const safe = GnosisSafeL2.attach(template);
  let tx = await safe.setup(
    [signers.signer_0.address],
    1,
    AddressZero,
    '0x',
    AddressZero,
    AddressZero,
    0,
    AddressZero
  );
  await tx.wait();

  const L1VotingContract = await ethers.getContractFactory('SnapshotXL1Voting');
  const L1AuthFactory = await starknet.getContractFactory('L1AuthMock');
  const L1Auth = await L1AuthFactory.deploy();
  const L1Vote = await L1VotingContract.deploy(starknetCore, L1Auth.address);

  return {
    L1Vote: L1Vote as any,
    L1Auth: L1Auth as any,
    safe: safe as any,
  };
}

describe('Snapshot X L1 Voting Contract:', () => {
  describe('Set up', async () => {
    it('can initialize and set up the contract', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { L1Vote, L1Auth } = await baseSetup({ signer_0, signer_1 });
      expect(await L1Vote.starknetCore()).to.equal(starknetCore);
      expect(await L1Vote.votingAuthL1()).to.equal(L1Auth.address);
    });
  });

  describe('Vote', async () => {
    it('can vote submit a vote from an EOA', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { L1Vote } = await baseSetup({ signer_0, signer_1 });
      await expect(
        L1Vote.voteOnL1(voteA.votingContract, voteA.proposalID, voteA.choice, {
          from: signer_0.address,
          gasLimit: 6000000,
        })
      )
        .to.emit(L1Vote, 'L1VoteSubmitted')
        .withArgs(voteA.votingContract, voteA.proposalID, voteA.choice, signer_0.address);
    });

    it('can submit a vote from a safe', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { L1Vote, safe } = await baseSetup({ signer_0, signer_1 });
      expect(
        await executeContractCallWithSigners(
          safe,
          L1Vote,
          'voteOnL1',
          [voteA.votingContract, voteA.proposalID, voteA.choice],
          [signer_0]
        )
      )
        .to.emit(L1Vote, 'L1VoteSubmitted')
        .withArgs(voteA.votingContract, voteA.proposalID, voteA.choice, safe.address);
    });

    it('should revert if an invalid vote is submitted', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { L1Vote } = await baseSetup({ signer_0, signer_1 });

      // This tx does revert however hardhat thinks it doesnt. Issue only occurs when Goerli is used,
      // works fine with devnet.
      await expect(
        L1Vote.voteOnL1(
          voteInvalidChoice.votingContract,
          voteInvalidChoice.proposalID,
          voteInvalidChoice.choice,
          {
            from: signer_0.address,
            gasLimit: 6000000,
          }
        )
      ).to.be.revertedWith('Invalid choice');
    });

    it('should revert if an invalid vote is submitted', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { L1Vote } = await baseSetup({ signer_0, signer_1 });
      await expect(
        L1Vote.voteOnL1(
          voteInvalidChoice.votingContract,
          voteInvalidChoice.proposalID,
          voteInvalidChoice.choice,
          {
            from: signer_0.address,
            gasLimit: 6000000,
          }
        )
      ).to.be.revertedWith('Invalid choice');
    });
  });

  describe('Propose', async () => {
    it('can submit a proposal from an EOA', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { L1Vote } = await baseSetup({ signer_0, signer_1 });
      await expect(
        L1Vote.proposeOnL1(
          proposalA.votingContract,
          proposalA.executionHash,
          proposalA.metadataHash,
          proposalA.domain,
          {
            from: signer_0.address,
            gasLimit: 6000000,
          }
        )
      )
        .to.emit(L1Vote, 'L1ProposalSubmitted')
        .withArgs(
          proposalA.votingContract,
          proposalA.executionHash,
          proposalA.metadataHash,
          proposalA.domain,
          signer_0.address
        );
    });

    it('can submit a proposal from a safe', async () => {
      const [signer_0, signer_1] = await ethers.getSigners();
      const { L1Vote, safe } = await baseSetup({ signer_0, signer_1 });
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
          [signer_0]
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
