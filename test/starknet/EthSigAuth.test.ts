import { expect } from 'chai';
import { StarknetContract, Account } from 'hardhat/types';
import { ethers } from 'hardhat';
import { domain, Propose, proposeTypes, Vote, voteTypes } from '../shared/types';
import { computeHashOnElements } from 'starknet/dist/utils/hash';
import { utils } from '@snapshot-labs/sx';
import { ethereumSigAuthSetup } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';
import { _TypedDataEncoder } from 'ethers/lib/utils';

export const VITALIK_ADDRESS = BigInt('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');
export const AUTHENTICATE_METHOD = 'authenticate';
export const PROPOSAL_METHOD = 'propose';
export const VOTE_METHOD = 'vote';
export const METADATA_URI = 'Hello and welcome to Snapshot X. This is the future of governance.';

describe('Ethereum Signature Auth testing', () => {
  // Contracts
  let space: StarknetContract;
  let controller: Account;
  let ethSigAuth: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;

  // Proposal creation parameters
  let spaceAddress: string;
  let executionHash: string;
  let metadataUri: string;
  let metadataUriInts: utils.intsSequence.IntsSequence;
  let usedVotingStrategies1: string[];
  let usedVotingStrategiesHash1: string;
  let userVotingParamsAll1: string[][];
  let userVotingStrategyParamsFlatHash1: string;
  let executionStrategy: string;
  let executionParams: string[];
  let proposerEthAddress: string;
  let proposeCalldata: string[];

  // Additional parameters for voting
  let voterEthAddress: string;
  let proposalId: string;
  let choice: utils.choice.Choice;
  let usedVotingStrategies2: string[];
  let usedVotingStrategiesHash2: string;
  let userVotingParamsAll2: string[][];
  let userVotingStrategyParamsFlatHash2: string;
  let voteCalldata: string[];

  before(async function () {
    this.timeout(800000);
    const accounts = await ethers.getSigners();
    ({ space, controller, ethSigAuth, vanillaVotingStrategy, vanillaExecutionStrategy } =
      await ethereumSigAuthSetup());

    metadataUri = 'Hello and welcome to Snapshot X. This is the future of governance.';
    metadataUriInts = utils.intsSequence.IntsSequence.LEFromString(metadataUri);
    usedVotingStrategies1 = ['0x0'];
    userVotingParamsAll1 = [[]];
    executionStrategy = vanillaExecutionStrategy.address;
    spaceAddress = space.address;

    executionParams = ['0x01']; // Random params
    executionHash = computeHashOnElements(executionParams);
    usedVotingStrategiesHash1 = computeHashOnElements(usedVotingStrategies1);
    const userVotingStrategyParamsFlat1 = utils.encoding.flatten2DArray(userVotingParamsAll1);
    userVotingStrategyParamsFlatHash1 = computeHashOnElements(userVotingStrategyParamsFlat1);

    proposerEthAddress = accounts[0].address;
    proposeCalldata = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUriInts,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );

    voterEthAddress = accounts[0].address;
    proposalId = '0x1';
    choice = utils.choice.Choice.FOR;
    usedVotingStrategies2 = ['0x0'];
    userVotingParamsAll2 = [[]];
    usedVotingStrategiesHash2 = computeHashOnElements(usedVotingStrategies2);
    const userVotingStrategyParamsFlat2 = utils.encoding.flatten2DArray(userVotingParamsAll2);
    userVotingStrategyParamsFlatHash2 = computeHashOnElements(userVotingStrategyParamsFlat2);
    voteCalldata = utils.encoding.getVoteCalldata(
      voterEthAddress,
      proposalId,
      choice,
      usedVotingStrategies2,
      userVotingParamsAll2
    );
  });

  it('Should not authenticate an invalid signature', async () => {
    try {
      const accounts = await ethers.getSigners();
      const salt: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromHex('0x1');
      const spaceStr = utils.encoding.hexPadRight(space.address);
      const executionHashPadded = utils.encoding.hexPadRight(executionHash);
      const usedVotingStrategiesHashPadded1 = utils.encoding.hexPadRight(usedVotingStrategiesHash1);
      const userVotingStrategyParamsFlatHashPadded1 = utils.encoding.hexPadRight(
        userVotingStrategyParamsFlatHash1
      );
      const paddedProposerAddress = utils.encoding.hexPadRight(proposerEthAddress);
      const paddedExecutor = utils.encoding.hexPadRight(vanillaExecutionStrategy.address);
      const message: Propose = {
        space: spaceStr,
        proposerAddress: paddedProposerAddress,
        metadataUri: METADATA_URI,
        executor: paddedExecutor,
        executionParamsHash: executionHashPadded,
        usedVotingStrategiesHash: usedVotingStrategiesHashPadded1,
        userVotingStrategyParamsFlatHash: userVotingStrategyParamsFlatHashPadded1,
        salt: salt.toHex(),
      };

      const fakeData = [...proposeCalldata];

      const sig = await accounts[0]._signTypedData(domain, proposeTypes, message);
      const { r, s, v } = utils.encoding.getRSVFromSig(sig);

      // Data is signed with accounts[0] but the proposer is accounts[1] so it should fail
      fakeData[0] = accounts[1].address;

      await controller.invoke(ethSigAuth, 'authenticate', {
        r: r,
        s: s,
        v: v,
        salt: salt,
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: fakeData,
      });
      expect(1).to.deep.equal(2);
    } catch (err: any) {
      expect(err.message).to.contain('Invalid signature.');
    }
  });

  it('Should create a proposal and cast a vote', async () => {
    // -- Creates the proposal --
    {
      const accounts = await ethers.getSigners();
      const proposalSalt: utils.splitUint256.SplitUint256 =
        utils.splitUint256.SplitUint256.fromHex('0x01');

      const executionHashPadded = utils.encoding.hexPadRight(executionHash);
      const usedVotingStrategiesHashPadded1 = utils.encoding.hexPadRight(usedVotingStrategiesHash1);
      const userVotingStrategyParamsFlatHashPadded1 = utils.encoding.hexPadRight(
        userVotingStrategyParamsFlatHash1
      );
      const paddedProposerAddress = utils.encoding.hexPadRight(proposerEthAddress);
      const paddedExecutor = utils.encoding.hexPadRight(executionStrategy);

      const message: Propose = {
        space: spaceAddress,
        proposerAddress: paddedProposerAddress,
        metadataUri: METADATA_URI,
        executor: paddedExecutor,
        executionParamsHash: executionHashPadded,
        usedVotingStrategiesHash: usedVotingStrategiesHashPadded1,
        userVotingStrategyParamsFlatHash: userVotingStrategyParamsFlatHashPadded1,
        salt: proposalSalt.toHex(),
      };

      const sig = await accounts[0]._signTypedData(domain, proposeTypes, message);

      const { r, s, v } = utils.encoding.getRSVFromSig(sig);

      console.log('Creating proposal...');
      await controller.invoke(ethSigAuth, 'authenticate', {
        r: r,
        s: s,
        v: v,
        salt: proposalSalt,
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata,
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      // -- Attempts a replay attack on `propose` method --
      // Expected to fail
      try {
        console.log('Replaying transaction...');
        await controller.invoke(ethSigAuth, 'authenticate', {
          r: r,
          s: s,
          v: v,
          salt: proposalSalt,
          target: spaceAddress,
          function_selector: PROPOSE_SELECTOR,
          calldata: proposeCalldata,
        });
        throw { message: 'replay attack worked on `propose`' };
      } catch (err: any) {
        expect(err.message).to.contain('Salt already used');
      }

      // We can't directly compare the `info` object because we don't know for sure the value of `start_block` (and hence `end_block`),
      // so we compare it element by element.
      const _executionHash = proposal_info.proposal.execution_hash;
      expect(_executionHash).to.deep.equal(BigInt(executionHash));

      const _for = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(0));
      const against = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));
    }

    // -- Casts a vote FOR --
    {
      console.log('Casting a vote FOR...');
      const accounts = await ethers.getSigners();
      const spaceStr = utils.encoding.hexPadRight(space.address);
      const voteSalt = utils.splitUint256.SplitUint256.fromHex('0x02');
      const usedVotingStrategiesHashPadded2 = utils.encoding.hexPadRight(usedVotingStrategiesHash2);
      const userVotingStrategyParamsFlatHashPadded2 = utils.encoding.hexPadRight(
        userVotingStrategyParamsFlatHash2
      );
      const voterEthAddressPadded = utils.encoding.hexPadRight(voterEthAddress);

      const message: Vote = {
        space: spaceStr,
        voterAddress: voterEthAddressPadded,
        proposal: BigInt(proposalId).toString(16),
        choice: utils.choice.Choice.FOR,
        usedVotingStrategiesHash: usedVotingStrategiesHashPadded2,
        userVotingStrategyParamsFlatHash: userVotingStrategyParamsFlatHashPadded2,
        salt: voteSalt.toHex(),
      };
      const sig = await accounts[0]._signTypedData(domain, voteTypes, message);

      const { r, s, v } = utils.encoding.getRSVFromSig(sig);
      const voteCalldata = utils.encoding.getVoteCalldata(
        voterEthAddress,
        proposalId,
        utils.choice.Choice.FOR,
        usedVotingStrategies1,
        userVotingParamsAll1
      );
      await controller.invoke(ethSigAuth, 'authenticate', {
        r: r,
        s: s,
        v: v,
        salt: voteSalt,
        target: spaceAddress,
        function_selector: VOTE_SELECTOR,
        calldata: voteCalldata,
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      const _for = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(1));
      const against = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));

      // -- Attempts a replay attack on `vote` method --
      try {
        console.log('Replaying vote...');
        await controller.invoke(ethSigAuth, 'authenticate', {
          r: r,
          s: s,
          v: v,
          salt: voteSalt,
          target: spaceAddress,
          function_selector: VOTE_SELECTOR,
          calldata: voteCalldata,
        });
        throw { message: 'replay attack worked on `vote`' };
      } catch (err: any) {
        expect(err.message).to.contain('Salt already used');
      }
    }
  }).timeout(6000000);
});
