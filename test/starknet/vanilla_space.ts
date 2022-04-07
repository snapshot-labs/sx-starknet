import { StarknetContract } from 'hardhat/types/runtime';
import { starknet } from 'hardhat';
import { stark } from 'starknet';
import { SplitUint256, AGAINST, FOR, ABSTAIN } from './shared/types';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { expect } from 'chai';

const { getSelectorFromName } = stark;

const EXECUTE_METHOD = 'execute';
const PROPOSAL_METHOD = 'propose';
const VOTE_METHOD = 'vote';
const GET_PROPOSAL_INFO = 'get_proposal_info';
const GET_VOTE_INFO = 'get_vote_info';
const VOTING_DELAY = BigInt(0);
const VOTING_PERIOD = BigInt(20);
const PROPOSAL_THRESHOLD = SplitUint256.fromUint(BigInt(1));
const VITALIK_ADDRESS = BigInt(0xd8da6bf26964af9d7eed9e03e53415d37aa96045);

async function setup() {
  const vanillaSpaceFactory = await starknet.getContractFactory(
    './contracts/starknet/space/space.cairo'
  );
  const vanillaVotingStategyFactory = await starknet.getContractFactory(
    './contracts/starknet/strategies/vanilla.cairo'
  );
  const vanillaAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/authenticator/authenticator.cairo'
  );
  console.log('Deploying auth...');
  const vanillaAuthenticator = (await vanillaAuthenticatorFactory.deploy()) as StarknetContract;
  console.log('Deploying strat...');
  const vanillaVotingStrategy = (await vanillaVotingStategyFactory.deploy()) as StarknetContract;
  const voting_strategy = BigInt(vanillaVotingStrategy.address);
  const authenticator = BigInt(vanillaAuthenticator.address);
  console.log('Deploying space...');
  const vanillaSpace = (await vanillaSpaceFactory.deploy({
    _voting_delay: VOTING_DELAY,
    _voting_period: VOTING_PERIOD,
    _proposal_threshold: PROPOSAL_THRESHOLD,
    _voting_strategies: [voting_strategy],
    _authenticators: [authenticator],
  })) as StarknetContract;

  return {
    vanillaSpace,
    vanillaAuthenticator,
    vanillaVotingStrategy,
  };
}

describe('Space testing', () => {
  it('Simple Vote', async () => {
    console.log('Setup...');
    const { vanillaSpace, vanillaAuthenticator, vanillaVotingStrategy } = await setup();
    const space_contract = BigInt(vanillaSpace.address);
    const execution_hash = BigInt(1);
    const metadata_uri = strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    console.log(metadata_uri);
    const proposer_address = VITALIK_ADDRESS;
    const proposal_id = 1;
    const params: Array<bigint> = [];
    const eth_block_number = BigInt(1337);
    const calldata = [
      BigInt(vanillaVotingStrategy.address),
      proposer_address,
      execution_hash,
      BigInt(metadata_uri.length),
      ...metadata_uri,
      eth_block_number,
      BigInt(params.length),
      ...params,
    ];

    // -- Creates the proposal --
    {
      console.log('Creating proposal...');
      await vanillaAuthenticator.invoke(EXECUTE_METHOD, {
        to: space_contract,
        function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
        calldata,
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await vanillaSpace.call('get_proposal_info', {
        proposal_id: proposal_id,
      });

      // We can't directly compare the `info` object because we don't know for sure the value of `start_block` (and hence `end_block`),
      // so we compare it element by element (except start_block and end_block for which we simply compare their difference to `VOTING_PERIOD`).
      expect(proposal_info.proposal.execution_hash).to.deep.equal(execution_hash);
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
      const voter_address = proposer_address;
      const params: Array<BigInt> = [];
      console.log('Voting FOR...');
      await vanillaAuthenticator.invoke(EXECUTE_METHOD, {
        to: space_contract,
        function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
        calldata: [
          BigInt(vanillaVotingStrategy.address),
          voter_address,
          proposal_id,
          FOR,
          BigInt(params.length),
        ],
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await vanillaSpace.call('get_proposal_info', {
        proposal_id: proposal_id,
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
