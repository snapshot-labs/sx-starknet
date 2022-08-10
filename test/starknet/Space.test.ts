import { expect } from 'chai';
import { ethers } from 'hardhat';
import { StarknetContract, Account } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { vanillaSetup } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';

describe('Space Testing', () => {
  // Contracts
  let space: StarknetContract;
  let controller: Account;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;

  // Proposal creation parameters
  let spaceAddress: string;
  let metadataUri: utils.intsSequence.IntsSequence;
  let proposerEthAddress: string;
  let usedVotingStrategies1: string[];
  let userVotingParamsAll1: string[][];
  let executionStrategy: string;
  let executionParams: string[];
  let proposeCalldata: string[];

  // Additional parameters for voting
  let voterEthAddress: string;
  let proposalId: string;
  let choice: utils.choice.Choice;
  let usedVotingStrategies2: string[];
  let userVotingParamsAll2: string[][];
  let voteCalldata: string[];

  before(async function () {
    this.timeout(800000);

    ({ space, controller, vanillaAuthenticator, vanillaVotingStrategy, vanillaExecutionStrategy } =
      await vanillaSetup());

    metadataUri = utils.intsSequence.IntsSequence.LEFromString(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    proposerEthAddress = ethers.Wallet.createRandom().address;
    spaceAddress = space.address;
    usedVotingStrategies1 = [vanillaVotingStrategy.address];
    userVotingParamsAll1 = [[]];
    executionStrategy = vanillaExecutionStrategy.address;
    executionParams = [];
    proposeCalldata = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );

    voterEthAddress = ethers.Wallet.createRandom().address;
    proposalId = '0x1';
    choice = utils.choice.Choice.FOR;
    usedVotingStrategies2 = [vanillaVotingStrategy.address];
    userVotingParamsAll2 = [[]];
    voteCalldata = utils.encoding.getVoteCalldata(
      voterEthAddress,
      proposalId,
      choice,
      usedVotingStrategies2,
      userVotingParamsAll2
    );
  });

  it('Users should be able to create a proposal, cast a vote, and execute it', async () => {
    // -- Creates the proposal --
    {
      await vanillaAuthenticator.invoke('authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata,
      });

      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      const _for = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(0));
      const against = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));
    }
    // -- Casts a vote FOR --
    {
      await vanillaAuthenticator.invoke('authenticate', {
        target: spaceAddress,
        function_selector: VOTE_SELECTOR,
        calldata: voteCalldata,
      });

      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      const _for = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(1));
      const against = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));
    }

    // -- Executes the proposal --
    {
      await space.invoke('finalize_proposal', {
        proposal_id: proposalId,
        execution_params: executionParams,
      });
    }
  }).timeout(6000000);
});
