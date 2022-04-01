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

const { getSelectorFromName } = stark;

describe('Space testing', () => {
  it('Simple Vote', async () => {
    const { vanillaSpace, vanillaAuthenticator, vanillaVotingStrategy } = await setup();
    const spaceContract = BigInt(vanillaSpace.address);
    const executionHash = new SplitUint256(BigInt(1), BigInt(2)); // Dummy uint256
    const metadataUri = strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    const proposerAddress = VITALIK_ADDRESS;
    const proposalId = 1;
    const params: Array<bigint> = [];
    const ethBlockNumber = BigInt(1337);
    const calldata = [
      proposerAddress,
      executionHash.low,
      executionHash.high,
      BigInt(metadataUri.length),
      ...metadataUri,
      ethBlockNumber,
      BigInt(params.length),
      ...params,
    ];

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
      const voter_address = proposerAddress;
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

  // TODO: how can we do tests that are expected to fail?
  // it('Fails if proposing without going through the authenticator', async () => {
  //   const { vanillaSpace, vanillaAuthenticator, vanillaVotingStrategy } = await setup();
  //   const execution_hash = BigInt(1);
  //   const metadata_uri = BigInt(2);
  //   const proposer_address = VITALIK_ADDRESS;

  //   const proposal_id = await vanillaSpace.call(PROPOSAL_METHOD, {
  //     proposer_address: proposer_address,
  //     execution_hash: execution_hash,
  //     metadata_uri: metadata_uri,
  //   });
  // }).timeout(60000);

  // TODO: how can we do tests that are expected to fail?
  // it('Fails if voting without going through the authenticator', async () => {
  //   const { vanillaSpace, vanillaAuthenticator, vanillaVotingStrategy } = await setup();
  //   const voter_address = VITALIK_ADDRESS;
  //   const proposal_id = 1;
  //   const choice = ABSTAIN;

  //   const proposal_id = await vanillaSpace.call(VOTE_METHOD, {
  //     proposer_address: proposer_address,
  //     proposal_id: proposal_id,
  //     choice: choice,
  //   });
  // }).timeout(60000);
});
