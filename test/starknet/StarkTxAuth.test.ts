import { expect } from 'chai';
import { starknet } from 'hardhat';
import { StarknetContract, Account } from 'hardhat/types';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { SplitUint256, Choice } from '../shared/types';
import { getProposeCalldata, getVoteCalldata } from '../shared/helpers';
import { starkTxAuthSetup } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';

const VITALIK_ADDRESS = BigInt('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');

describe('StarkNet Tx Auth testing', () => {
  // Contracts
  let space: StarknetContract;
  let controller: Account;
  let starknetTxAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;

  // Proposal creation parameters
  let spaceAddress: bigint;
  let metadataUri: bigint[];
  let proposerAccount: Account;
  let proposerAddress: string;
  let usedVotingStrategies1: bigint[];
  let userVotingParamsAll1: bigint[][];
  let executionStrategy: bigint;
  let executionParams: bigint[];
  let proposeCalldata: bigint[];

  // Additional parameters for voting
  let voterAccount: Account;
  let voterAddress: string;
  let proposalId: bigint;
  let choice: Choice;
  let usedVotingStrategies2: bigint[];
  let userVotingParamsAll2: bigint[][];
  let voteCalldata: bigint[];

  before(async function () {
    this.timeout(800000);
    proposerAccount = (await starknet.deployAccount('OpenZeppelin')) as Account;
    voterAccount = (await starknet.deployAccount('OpenZeppelin')) as Account;
    ({
      space,
      controller,
      starknetTxAuthenticator,
      vanillaVotingStrategy,
      vanillaExecutionStrategy,
    } = await starkTxAuthSetup());

    metadataUri = strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    proposerAddress = proposerAccount.starknetContract.address;
    spaceAddress = BigInt(space.address);
    usedVotingStrategies1 = [BigInt(vanillaVotingStrategy.address)];
    userVotingParamsAll1 = [[]];
    executionStrategy = BigInt(vanillaExecutionStrategy.address);
    executionParams = [];
    proposeCalldata = getProposeCalldata(
      proposerAddress,
      metadataUri,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );

    voterAddress = voterAccount.starknetContract.address;
    proposalId = BigInt(1);
    choice = Choice.FOR;
    usedVotingStrategies2 = [BigInt(vanillaVotingStrategy.address)];
    userVotingParamsAll2 = [[]];
    voteCalldata = getVoteCalldata(
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
      throw 'error';
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
      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      const _for = SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(0));
      const against = SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = SplitUint256.fromObj(proposal_info.power_abstain).toUint();
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
      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      const _for = SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(1));
      const against = SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));
    }
  }).timeout(6000000);
});
