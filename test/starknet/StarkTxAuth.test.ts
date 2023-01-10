import { expect } from 'chai';
import { starknet } from 'hardhat';
import { StarknetContract, Account } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { starkTxAuthSetup } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';
import { getAccount } from '../utils/deploy';

const VITALIK_ADDRESS = '0xd8da6bf26964af9d7eed9e03e53415d37aa96045';

describe('StarkNet Tx Auth testing', () => {
  // Contracts
  let space: StarknetContract;
  let controller: Account;
  let starknetTxAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;

  // Proposal creation parameters
  let spaceAddress: string;
  let metadataUri: utils.intsSequence.IntsSequence;
  let proposerAccount: Account;
  let proposerAddress: string;
  let usedVotingStrategies1: string[];
  let userVotingParamsAll1: string[][];
  let executionStrategy: string;
  let executionParams: string[];
  let proposeCalldata: string[];

  // Additional parameters for voting
  let voterAccount: Account;
  let voterAddress: string;
  let proposalId: string;
  let choice: utils.choice.Choice;
  let usedVotingStrategies2: string[];
  let userVotingParamsAll2: string[][];
  let voteCalldata: string[];

  before(async function () {
    this.timeout(800000);
    proposerAccount = await getAccount(5);
    voterAccount = await getAccount(6);
    ({
      space,
      controller,
      starknetTxAuthenticator,
      vanillaVotingStrategy,
      vanillaExecutionStrategy,
    } = await starkTxAuthSetup());

    metadataUri = utils.intsSequence.IntsSequence.LEFromString(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    proposerAddress = proposerAccount.starknetContract.address;
    spaceAddress = space.address;
    usedVotingStrategies1 = ['0x0'];
    userVotingParamsAll1 = [[]];
    executionStrategy = vanillaExecutionStrategy.address;
    executionParams = [];
    proposeCalldata = utils.encoding.getProposeCalldata(
      proposerAddress,
      metadataUri,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );

    voterAddress = voterAccount.starknetContract.address;
    proposalId = '0x1';
    choice = utils.choice.Choice.FOR;
    usedVotingStrategies2 = ['0x0'];
    userVotingParamsAll2 = [[]];
    voteCalldata = utils.encoding.getVoteCalldata(
      voterAddress,
      proposalId,
      choice,
      usedVotingStrategies2,
      userVotingParamsAll2
    );
  });

  it('Should not authenticate an invalid user', async () => {
    const fakeData = [...proposeCalldata];
    fakeData[0] = VITALIK_ADDRESS;
    try {
      await proposerAccount.invoke(starknetTxAuthenticator, 'authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: fakeData,
      });
      throw { message: 'error' };
    } catch (err: any) {
      expect(err.message).to.contain('Incorrect caller');
    }
  });

  it('Should create a proposal and cast a vote', async () => {
    // -- Creates the proposal --
    {
      console.log('Creating proposal...');
      await proposerAccount.invoke(starknetTxAuthenticator, 'authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata,
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await space.call('getProposalInfo', {
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
      console.log('Casting a vote FOR...');
      await voterAccount.invoke(starknetTxAuthenticator, 'authenticate', {
        target: spaceAddress,
        function_selector: VOTE_SELECTOR,
        calldata: voteCalldata,
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await space.call('getProposalInfo', {
        proposal_id: proposalId,
      });

      const _for = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(1));
      const against = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));
    }
  }).timeout(6000000);
});
