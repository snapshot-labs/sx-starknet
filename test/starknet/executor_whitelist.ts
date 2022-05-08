import { stark } from 'starknet';
import { SplitUint256, FOR } from './shared/types';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { expect } from 'chai';
import {
  vanillaSetup,
  VITALIK_ADDRESS,
  EXECUTE_METHOD,
  PROPOSAL_METHOD,
} from './shared/setup';
import { StarknetContract } from 'hardhat/types';
import { Account } from '@shardlabs/starknet-hardhat-plugin/dist/account';

const { getSelectorFromName } = stark;

describe('Whitelist testing', () => {
  let vanillaSpace: StarknetContract;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let zodiacRelayer: StarknetContract;
  let account: Account;
  const executionHash = new SplitUint256(BigInt(1), BigInt(2)); // Dummy uint256
  const metadataUri = strToShortStringArr(
    'Hello and welcome to Snapshot X. This is the future of governance.'
  );
  const proposerAddress = { value: VITALIK_ADDRESS };
  const proposalId = 1;
  const votingParams: Array<bigint> = [];
  let executionParams: Array<bigint>;
  const ethBlockNumber = BigInt(1337);
  const l1_zodiac_module = BigInt('0xaaaaaaaaaaaa');
  let used_voting_strategies: Array<bigint>;
  let calldata: Array<bigint>;
  let calldata2: Array<bigint>;
  let spaceContract: bigint;

  before(async function () {
    this.timeout(800000);

    ({ vanillaSpace, vanillaAuthenticator, vanillaVotingStrategy, zodiacRelayer, account } =
      await vanillaSetup());
    executionParams = [BigInt(l1_zodiac_module)];
    spaceContract = BigInt(vanillaSpace.address);
    used_voting_strategies = [BigInt(vanillaVotingStrategy.address)];

    calldata = [
      proposerAddress.value,
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

    // Same as calldata except executor is VITALIK_ADDRESS
    calldata2 = [
      proposerAddress.value,
      executionHash.low,
      executionHash.high,
      BigInt(metadataUri.length),
      ...metadataUri,
      ethBlockNumber,
      VITALIK_ADDRESS,
      BigInt(used_voting_strategies.length),
      ...used_voting_strategies,
      BigInt(votingParams.length),
      ...votingParams,
      BigInt(executionParams.length),
      ...executionParams,
    ];
  });

  it('Should create a proposal for a whitelisted executor', async () => {
    {
      await vanillaAuthenticator.invoke(EXECUTE_METHOD, {
        target: spaceContract,
        function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
        calldata,
      });
    }
  });

  it('Should correctly remove two executors', async () => {
    const randomAddr = 0x45;
    const hash = await account.invoke(vanillaSpace, 'remove_executors', {
      to_remove: [BigInt(zodiacRelayer.address), randomAddr],
    });

    try {
      // Try to create a proposal, should fail because it just got removed
      // from the whitelist
      await vanillaAuthenticator.invoke(EXECUTE_METHOD, {
        target: spaceContract,
        function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
        calldata,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Invalid executor');
    }
  });

  it('Should correctly add two executors', async () => {
    const hash = await account.invoke(vanillaSpace, 'add_executors', {
      to_add: [BigInt(zodiacRelayer.address), VITALIK_ADDRESS],
    });

    await vanillaAuthenticator.invoke(EXECUTE_METHOD, {
      target: spaceContract,
      function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
      calldata: calldata2,
    });
  });
});
