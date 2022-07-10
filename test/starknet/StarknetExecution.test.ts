import { expect } from 'chai';
import { ethers } from 'hardhat';
import { StarknetContract, Account } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { starknetExecutionSetup } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR, AUTHENTICATE_SELECTOR } from '../shared/constants';

export interface Call {
  to: bigint;
  functionSelector: bigint;
  calldata: bigint[];
}

/**
 * For more info about the starknetExecutionParams layout, please see `contracts/starknet/execution_strategies/starknet.cairo`.
 */
export function createStarknetExecutionParams(callArray: Call[]): bigint[] {
  if (!callArray || callArray.length == 0) {
    return [];
  }

  // 1 because we need to count data_offset
  // 4 because there are four elements: `to`, `function_selector`, `calldata_len` and `calldata_offset`
  const dataOffset = BigInt(1 + callArray.length * 4);

  const executionParams = [dataOffset];
  let calldataIndex = 0;

  // First, layout the calls
  callArray.forEach((call) => {
    const subArr: bigint[] = [
      call.to,
      call.functionSelector,
      BigInt(call.calldata.length),
      BigInt(calldataIndex),
    ];
    calldataIndex += call.calldata.length;
    executionParams.push(...subArr);
  });

  // Then layout the calldata
  callArray.forEach((call) => {
    executionParams.push(...call.calldata);
  });
  return executionParams;
}

describe('Space Testing', () => {
  // Contracts
  let space: StarknetContract;
  let controller: Account;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let starknetExecutionStrategy: StarknetContract;

  // Proposal creation parameters
  let spaceAddress: bigint;
  let metadataUri: bigint[];
  let proposerEthAddress: string;
  let usedVotingStrategies1: bigint[];
  let userVotingParamsAll1: bigint[][];
  let executionStrategy: bigint;
  let executionParams: bigint[];
  let proposeCalldata: bigint[];

  // Additional parameters for voting
  let voterEthAddress: string;
  let proposalId: bigint;
  let choice: utils.choice.Choice;
  let usedVotingStrategies2: bigint[];
  let userVotingParamsAll2: bigint[][];
  let voteCalldata: bigint[];

  before(async function () {
    this.timeout(800000);

    ({ space, controller, vanillaAuthenticator, vanillaVotingStrategy, starknetExecutionStrategy } =
      await starknetExecutionSetup());

    metadataUri = utils.strings.strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    proposerEthAddress = ethers.Wallet.createRandom().address;
    spaceAddress = BigInt(space.address);
    usedVotingStrategies1 = [BigInt(vanillaVotingStrategy.address)];
    userVotingParamsAll1 = [[]];
    executionStrategy = BigInt(starknetExecutionStrategy.address);

    // For the execution of the proposal, we create 2 new dummy proposals
    const callCalldata1 = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      BigInt(1234),
      usedVotingStrategies1,
      userVotingParamsAll1,
      []
    );
    const callCalldata2 = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      BigInt(4567),
      usedVotingStrategies1,
      userVotingParamsAll1,
      []
    );
    const callCalldata3 = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      BigInt(456789),
      usedVotingStrategies1,
      userVotingParamsAll1,
      []
    );
    const call1: Call = {
      to: BigInt(vanillaAuthenticator.address),
      functionSelector: AUTHENTICATE_SELECTOR,
      calldata: [spaceAddress, PROPOSE_SELECTOR, BigInt(callCalldata1.length), ...callCalldata1],
    };
    const call2: Call = {
      to: BigInt(vanillaAuthenticator.address),
      functionSelector: AUTHENTICATE_SELECTOR,
      calldata: [spaceAddress, PROPOSE_SELECTOR, BigInt(callCalldata2.length), ...callCalldata2],
    };
    const call3: Call = {
      to: BigInt(vanillaAuthenticator.address),
      functionSelector: AUTHENTICATE_SELECTOR,
      calldata: [spaceAddress, PROPOSE_SELECTOR, BigInt(callCalldata3.length), ...callCalldata3],
    };
    executionParams = createStarknetExecutionParams([call1, call2, call3]);

    proposeCalldata = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );

    voterEthAddress = ethers.Wallet.createRandom().address;
    proposalId = BigInt(1);
    choice = utils.choice.Choice.FOR;
    usedVotingStrategies2 = [BigInt(vanillaVotingStrategy.address)];
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

    // -- Executes the proposal, which should create 2 new dummy proposal in the same space
    {
      await space.invoke('finalize_proposal', {
        proposal_id: proposalId,
        execution_params: executionParams,
      });

      let { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: 2,
      });
      // We can check that the proposal was successfully created by checking the execution strategy
      // as it will be zero if the new proposal was not created
      expect(proposal_info.proposal.executor).to.deep.equal(BigInt(1234));

      // Same for second dummy proposal
      ({ proposal_info } = await space.call('get_proposal_info', {
        proposal_id: 3,
      }));
      expect(proposal_info.proposal.executor).to.deep.equal(BigInt(4567));

      ({ proposal_info } = await space.call('get_proposal_info', {
        proposal_id: 4,
      }));
      expect(proposal_info.proposal.executor).to.deep.equal(BigInt(456789));
    }
  }).timeout(6000000);
});
