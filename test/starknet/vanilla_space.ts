import { StarknetContract } from 'hardhat/types/runtime';
import { starknet } from 'hardhat';
import { stark } from 'starknet';
import { SplitUint256, AGAINST, FOR, ABSTAIN } from './shared/types';
import { expect } from 'chai';

const { getSelectorFromName } = stark;

const EXECUTE_METHOD = 'execute';
const PROPOSAL_METHOD = 'propose';
const VOTE_METHOD = 'vote';
const GET_PROPOSAL_INFO = 'get_proposal_info';
const GET_VOTE_INFO = 'get_vote_info';
const VOTING_DELAY = BigInt(1);
const VOTING_PERIOD = BigInt(20);
const PROPOSAL_THRESHOLD = new SplitUint256(BigInt(1), BigInt(0));
const VITALIK_ADDRESS = BigInt(0xd8da6bf26964af9d7eed9e03e53415d37aa96045);

async function setup() {
  const vanillaSpaceFactory = await starknet.getContractFactory(
    './contracts/starknet/space/space.cairo'
  );
  const vanillaVotingStategyFactory = await starknet.getContractFactory(
    './contracts/starknet/strategies/vanilla_voting_strategy.cairo'
  );
  const vanillaAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/authenticator/authenticator.cairo'
  );
  const vanillaAuthenticator = (await vanillaAuthenticatorFactory.deploy()) as StarknetContract;
  const vanillaVotingStrategy = (await vanillaVotingStategyFactory.deploy()) as StarknetContract;
  const voting_strategy = BigInt(vanillaVotingStrategy.address);
  const authenticator = BigInt(vanillaAuthenticator.address);
  const vanillaSpace = (await vanillaSpaceFactory.deploy({
    _voting_delay: VOTING_DELAY,
    _voting_period: VOTING_PERIOD,
    _proposal_threshold: PROPOSAL_THRESHOLD,
    _voting_strategy: voting_strategy,
    _authenticator: authenticator,
  })) as StarknetContract;

  return {
    vanillaSpace,
    vanillaAuthenticator,
    vanillaVotingStrategy,
  };
}

describe('Space testing', () => {
  it('Creates a proposal', async () => {
    const { vanillaSpace, vanillaAuthenticator, vanillaVotingStrategy } = await setup();
    const space_contract = BigInt(vanillaSpace.address);
    const execution_hash = BigInt(1);
    const metadata_uri = BigInt(2);
    const proposer_address = VITALIK_ADDRESS;

    const {
      retdata_len: len,
      retdata: [proposal_id],
    } = await vanillaAuthenticator.call(EXECUTE_METHOD, {
      to: space_contract,
      function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
      calldata: [proposer_address, execution_hash, metadata_uri],
    });
    expect(proposal_id).to.deep.equal(BigInt(1));

    const { proposal_info: info } = await vanillaSpace.call('get_proposal_info', {
      proposal_id: proposal_id,
    });

    // We can't directly compare the `info` object because we don't know for sure the value of `start_block` (and hence `end_block`),
    // so we compare it element by element (except start_block and end_block for which we simply check their difference)
    expect(info.proposal.execution_hash).to.deep.equal(execution_hash);
    expect(info.proposal.metadata_uri).to.deep.equal(metadata_uri);
    expect(info.proposal.end_block - info.proposal.start_block).to.deep.equal(VOTING_PERIOD);

    expect(info.power_against).to.deep.equal(BigInt(0));
    expect(info.power_for).to.deep.equal(BigInt(0));
    expect(info.power_abstain).to.deep.equal(BigInt(0));
  }).timeout(60000);

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
