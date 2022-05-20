import { stark } from 'starknet';
import { SplitUint256, FOR } from './shared/types';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { expect } from 'chai';
import {
  starknetTxSetup,
  VITALIK_ADDRESS,
  AUTHENTICATE_METHOD,
  PROPOSAL_METHOD,
  VOTE_METHOD,
} from './shared/setup';
import { StarknetContract } from 'hardhat/types';
import { Account } from '@shardlabs/starknet-hardhat-plugin/dist/account';

const { getSelectorFromName } = stark;

describe('Starknet Tx Auth testing', () => {
  let vanillaSpace: StarknetContract;
  let starknetTxAuth: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let zodiacRelayer: StarknetContract;
  const executionHash = new SplitUint256(BigInt(1), BigInt(2)); // Dummy uint256
  const metadataUri = strToShortStringArr(
    'Hello and welcome to Snapshot X. This is the future of governance.'
  );
  let proposerAddress: bigint;
  const proposalId = 1;
  const votingParams: Array<bigint> = [];
  let used_voting_strategies: Array<bigint>;
  let executionParams: Array<bigint>;
  const ethBlockNumber = BigInt(1337);
  const l1_zodiac_module = BigInt('0xaaaaaaaaaaaa');
  let calldata: Array<bigint>;
  let spaceContract: bigint;
  let account: Account;

  before(async function () {
    this.timeout(800000);

    ({ vanillaSpace, starknetTxAuth, vanillaVotingStrategy, zodiacRelayer, account } =
      await starknetTxSetup());
    executionParams = [BigInt(l1_zodiac_module)];
    spaceContract = BigInt(vanillaSpace.address);
    used_voting_strategies = [BigInt(vanillaVotingStrategy.address)];
    proposerAddress = BigInt(account.starknetContract.address);

    calldata = [
      proposerAddress,
      executionHash.low,
      executionHash.high,
      BigInt(metadataUri.length),
      ...metadataUri,
      ethBlockNumber,
      BigInt(zodiacRelayer.address),
      BigInt(used_voting_strategies.length),
      ...used_voting_strategies,
      BigInt(votingParams.length),
      ...votingParams,
      BigInt(executionParams.length),
      ...executionParams,
    ];
  });

  it('Should not authenticate an invalid user', async () => {
    try {
      const fake_data = [...calldata];
      fake_data[0] = VITALIK_ADDRESS;

      await account.invoke(starknetTxAuth, AUTHENTICATE_METHOD, {
        target: spaceContract,
        function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
        calldata: fake_data,
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
      await account.invoke(starknetTxAuth, AUTHENTICATE_METHOD, {
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
      const voter_address = proposerAddress;
      const votingparams: Array<BigInt> = [];
      const used_voting_strategies = [BigInt(vanillaVotingStrategy.address)];
      await account.invoke(starknetTxAuth, AUTHENTICATE_METHOD, {
        target: spaceContract,
        function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
        calldata: [
          voter_address,
          proposalId,
          FOR,
          BigInt(used_voting_strategies.length),
          ...used_voting_strategies,
          BigInt(votingParams.length),
          ...votingParams,
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
  }).timeout(6000000);
});