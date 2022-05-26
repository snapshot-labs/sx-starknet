import { stark } from 'starknet';
import { SplitUint256, FOR } from './shared/types';
import { flatten2DArray } from './shared/helpers';
import { createStarknetExecutionParams, Call } from './shared/executionParams';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { expect } from 'chai';
import {
  vanillaSetup,
  VITALIK_ADDRESS,
  AUTHENTICATE_METHOD,
  PROPOSAL_METHOD,
  VOTE_METHOD,
  MIN_VOTING_DURATION,
  MAX_VOTING_DURATION,
  starknetExecSetup,
} from './shared/setup';
import { StarknetContract } from 'hardhat/types';
import { computeHashOnElements } from 'starknet/dist/utils/hash';
import { toBN } from 'starknet/dist/utils/number';

const { getSelectorFromName } = stark;

describe('Starknet Execution', () => {
  let vanillaSpace: StarknetContract;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let starknetExec: StarknetContract;
  let executionHash: SplitUint256;
  const metadataUri = strToShortStringArr(
    'Hello and welcome to Snapshot X. This is the future of governance.'
  );
  const proposerAddress = { value: VITALIK_ADDRESS };
  const proposalId = 1;
  const votingParamsAll: bigint[][] = [[]];
  let used_voting_strategies: Array<bigint>;
  let executionParams: Array<bigint>;
  const ethBlockNumber = BigInt(1337);
  let calldata: Array<bigint>;
  let spaceContract: bigint;

  before(async function () {
    this.timeout(800000);

    ({ vanillaSpace, vanillaAuthenticator, vanillaVotingStrategy, starknetExec } =
      await starknetExecSetup());

    spaceContract = BigInt(vanillaSpace.address);
    used_voting_strategies = [BigInt(vanillaVotingStrategy.address)];

    // Cairo cannot handle 2D arrays in calldata so we must flatten the data then reconstruct the individual arrays inside the contract
    const votingParamsAllFlat = flatten2DArray(votingParamsAll);
    const emptyExecutionParams: bigint[] = [];

    executionHash = new SplitUint256(BigInt(1), BigInt(2)); // Dummy
    const call_calldata = [
      proposerAddress.value,
      executionHash.low,
      executionHash.high,
      BigInt(metadataUri.length),
      ...metadataUri,
      ethBlockNumber,
      BigInt(starknetExec.address),
      BigInt(used_voting_strategies.length),
      ...used_voting_strategies,
      BigInt(votingParamsAllFlat.length),
      ...votingParamsAllFlat,
      BigInt(emptyExecutionParams.length),
      ...emptyExecutionParams,
    ];

    // To better understand how this is constructed, please read the Starknet execution strategy comments.
    const call: Call = {
      to: BigInt(vanillaAuthenticator.address),
      functionSelector: BigInt(getSelectorFromName(AUTHENTICATE_METHOD)),
      calldata: [
        spaceContract,
        BigInt(getSelectorFromName(PROPOSAL_METHOD)),
        BigInt(call_calldata.length),
        ...call_calldata,
      ],
    };
    const calls = [call];
    executionParams = createStarknetExecutionParams(calls);
    const executionParamsBN = executionParams.map((n) => toBN(n.toString()));
    executionHash = SplitUint256.fromUint(BigInt(computeHashOnElements(executionParamsBN)));

    calldata = [
      proposerAddress.value,
      executionHash.low,
      executionHash.high,
      BigInt(metadataUri.length),
      ...metadataUri,
      ethBlockNumber,
      BigInt(starknetExec.address),
      BigInt(used_voting_strategies.length),
      ...used_voting_strategies,
      BigInt(votingParamsAllFlat.length),
      ...votingParamsAllFlat,
      BigInt(executionParams.length),
      ...executionParams,
    ];
  });

  it('Should create a proposal, cast a vote, execute the proposal, and vote on the newly created proposal', async () => {
    // -- Creates the proposal --
    {
      console.log('Creating proposal...');
      await vanillaAuthenticator.invoke(AUTHENTICATE_METHOD, {
        target: spaceContract,
        function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
        calldata,
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await vanillaSpace.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      // We can't directly compare the `info` object because we don't know for sure the value of `start_block` (and hence `end_block`),
      // so we compare it element by element.
      const _executionHash = SplitUint256.fromObj(proposal_info.proposal.execution_hash);
      expect(_executionHash).to.deep.equal(executionHash);

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
      const voter_address = proposerAddress.value;
      const votingParamsAll: bigint[][] = [[]];
      // Cairo cannot handle 2D arrays in calldata so we must flatten the data then reconstruct the individual arrays inside the contract
      const votingParamsAllFlat = flatten2DArray(votingParamsAll);
      const used_voting_strategies = [BigInt(vanillaVotingStrategy.address)];
      await vanillaAuthenticator.invoke(AUTHENTICATE_METHOD, {
        target: spaceContract,
        function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
        calldata: [
          voter_address,
          proposalId,
          FOR,
          BigInt(used_voting_strategies.length),
          ...used_voting_strategies,
          BigInt(votingParamsAllFlat.length),
          ...votingParamsAllFlat,
        ],
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await vanillaSpace.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      const _for = SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(1));
      const against = SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));
    }

    // -- Finalize Proposal and execute --
    {
      console.log('Finalizing proposal');
      await vanillaSpace.invoke('finalize_proposal', {
        proposal_id: 1,
        execution_params: executionParams,
      });
    }

    // -- Execution should have created a new proposal; vote on it!
    {
      console.log('Casting a vote FOR...');
      const newProposalId = proposalId + 1;
      const voter_address = proposerAddress.value;
      const votingParamsAll: bigint[][] = [[]];
      // Cairo cannot handle 2D arrays in calldata so we must flatten the data then reconstruct the individual arrays inside the contract
      const votingParamsAllFlat = flatten2DArray(votingParamsAll);
      const used_voting_strategies = [BigInt(vanillaVotingStrategy.address)];
      await vanillaAuthenticator.invoke(AUTHENTICATE_METHOD, {
        target: spaceContract,
        function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
        calldata: [
          voter_address,
          newProposalId,
          FOR,
          BigInt(used_voting_strategies.length),
          ...used_voting_strategies,
          BigInt(votingParamsAllFlat.length),
          ...votingParamsAllFlat,
        ],
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await vanillaSpace.call('get_proposal_info', {
        proposal_id: newProposalId,
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
