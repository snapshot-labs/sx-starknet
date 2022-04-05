import { stark } from 'starknet';
import { SplitUint256, FOR } from './shared/types';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { expect } from 'chai';
import {
  setup,
  VITALIK_ADDRESS,
  EXECUTE_METHOD,
  PROPOSAL_METHOD,
  VOTE_METHOD,
  VOTING_PERIOD,
} from './shared/helpers';
import { StarknetContract } from 'hardhat/types';

const { getSelectorFromName } = stark;

describe('Space testing', () => {
  let vanillaSpace: StarknetContract;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let zodiacRelayer: StarknetContract;
  const executionHash = new SplitUint256(BigInt(1), BigInt(2)); // Dummy uint256
  const metadataUri = strToShortStringArr(
    'Hello and welcome to Snapshot X. This is the future of governance.'
  );
  const proposerAddress = {value: VITALIK_ADDRESS};
  const proposalId = 1;
  const votingParams: Array<bigint> = [];
  let executionParams: Array<bigint>;
  const ethBlockNumber = BigInt(1337);
  let calldata: Array<bigint>;
  let spaceContract: bigint;

  before(async function () {
    ({vanillaSpace, vanillaAuthenticator, vanillaVotingStrategy, zodiacRelayer} = await setup());
    executionParams = [BigInt(zodiacRelayer.address)];
    spaceContract = BigInt(vanillaSpace.address);

    calldata = [
      proposerAddress.value,
      executionHash.low,
      executionHash.high,
      BigInt(metadataUri.length),
      ...metadataUri,
      ethBlockNumber,
      BigInt(votingParams.length),
      ...votingParams,
      BigInt(executionParams.length),
      ...executionParams,
    ]
  });

  // `to.be.reverted` doesn't work yet with starknet (to my knowledge)
  // it('Fails if proposing without going through the authenticator', async () => {
  //   console.log('Creating proposal...');
  //   let invoke = vanillaSpace.invoke(PROPOSAL_METHOD, {
  //     proposer_address: proposerAddress,
  //     execution_hash: executionHash,
  //     metadata_uri: metadataUri,
  //     ethereum_block_number: ethBlockNumber,
  //     voting_params: votingParams,
  //     execution_params: executionParams,
  //   });
  //   expect (await invoke).to.be.reverted;
  // });

  it('Should create a proposal and cast a vote', async () => {
    // -- Creates the proposal --
    {
      console.log('Creating proposal...');
      await vanillaAuthenticator.invoke(EXECUTE_METHOD, {
        to: spaceContract,
        function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
        calldata,
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await vanillaSpace.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      // We can't directly compare the `info` object because we don't know for sure the value of `start_block` (and hence `end_block`),
      // so we compare it element by element (except start_block and end_block for which we simply compare their difference to `VOTING_PERIOD`).
      const _executionHash = SplitUint256.fromObj(proposal_info.proposal.execution_hash);
      expect(_executionHash).to.deep.equal(executionHash);
      expect(
        proposal_info.proposal.end_timestamp - proposal_info.proposal.start_timestamp
      ).to.deep.equal(VOTING_PERIOD);

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
      const params: Array<BigInt> = [];
      await vanillaAuthenticator.invoke(EXECUTE_METHOD, {
        to: spaceContract,
        function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
        calldata: [voter_address, proposalId, FOR, BigInt(params.length)],
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
  }).timeout(6000000);
});
