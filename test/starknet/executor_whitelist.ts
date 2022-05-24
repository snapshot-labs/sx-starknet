import { expect } from 'chai';
import { Contract } from 'ethers';
import { stark } from 'starknet';
import { starknet, ethers } from 'hardhat';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { zodiacRelayerSetup } from '../shared/setup';
import { flatten2DArray, getProposeCalldata, getVoteCalldata } from '../shared/helpers';
import { StarknetContract, Account } from 'hardhat/types';

const { getSelectorFromName } = stark;

describe('Whitelist testing', () => {
  // Contracts
  let mockStarknetMessaging: Contract;
  let space: StarknetContract;
  let controller: Account;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let zodiacRelayer: StarknetContract;
  let zodiacModule: Contract;
  let vanillaExecutionStrategy: StarknetContract;

  // Proposal creation parameters
  let spaceAddress: bigint;
  let executionHash: string;
  let metadataUri: bigint[];
  let proposerEthAddress: string;
  let usedVotingStrategies1: bigint[];
  let votingParamsAll1: bigint[][];
  let executionStrategy1: bigint;
  let executionParams1: bigint[];
  let ethBlockNumber: bigint;
  let proposeCalldata1: bigint[];

  // Alternative execution strategy parameters
  let executionStrategy2: bigint;
  let executionParams2: bigint[];
  let proposeCalldata2: bigint[];

  before(async function () {
    this.timeout(800000);

    ({
      space,
      controller,
      vanillaAuthenticator,
      vanillaVotingStrategy,
      zodiacRelayer,
      zodiacModule,
      mockStarknetMessaging,
    } = await zodiacRelayerSetup());

    const vanillaExecutionStrategyFactory = await starknet.getContractFactory(
      './contracts/starknet/execution_strategies/vanilla.cairo'
    );
    vanillaExecutionStrategy = await vanillaExecutionStrategyFactory.deploy();

    spaceAddress = BigInt(space.address);
    executionHash = '0x912ea662aac9d054ef5173da69723b88a5582cae2349f891998b6040cf9c2653'; // Random 32 byte hash
    metadataUri = strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    proposerEthAddress = ethers.Wallet.createRandom().address;
    ethBlockNumber = BigInt(1337);
    spaceAddress = BigInt(space.address);
    usedVotingStrategies1 = [BigInt(vanillaVotingStrategy.address)];
    votingParamsAll1 = [[]];
    executionStrategy1 = BigInt(zodiacRelayer.address);
    executionParams1 = [BigInt(zodiacModule.address)];
    proposeCalldata1 = getProposeCalldata(
      proposerEthAddress,
      executionHash,
      metadataUri,
      ethBlockNumber,
      executionStrategy1,
      usedVotingStrategies1,
      votingParamsAll1,
      executionParams1
    );

    executionStrategy2 = BigInt(vanillaExecutionStrategy.address);
    executionParams2 = [];
    proposeCalldata2 = getProposeCalldata(
      proposerEthAddress,
      executionHash,
      metadataUri,
      ethBlockNumber,
      executionStrategy2,
      usedVotingStrategies1,
      votingParamsAll1,
      executionParams2
    );
  });

  it('Should create a proposal for a whitelisted executor', async () => {
    {
      await vanillaAuthenticator.invoke('execute', {
        target: spaceAddress,
        function_selector: BigInt(getSelectorFromName('propose')),
        calldata: proposeCalldata1,
      });
    }
  });

  it('Should not be able to create a proposal with a non whitelisted executor', async () => {
    try {
      // proposeCalldata2 contains the vanilla execution strategy which is not whitelisted initially
      await vanillaAuthenticator.invoke('execute', {
        target: spaceAddress,
        function_selector: BigInt(getSelectorFromName('propose')),
        calldata: proposeCalldata2,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Invalid executor');
    }
  });

  it('The Controller can whitelist an executor', async () => {
    await controller.invoke(space, 'add_executors', {
      to_add: [BigInt(vanillaExecutionStrategy.address)],
    });

    await vanillaAuthenticator.invoke('execute', {
      target: spaceAddress,
      function_selector: BigInt(getSelectorFromName('propose')),
      calldata: proposeCalldata2,
    });
  });

  it('The controller can remove two executors', async () => {
    await controller.invoke(space, 'remove_executors', {
      to_remove: [BigInt(zodiacRelayer.address), BigInt(vanillaExecutionStrategy.address)],
    });

    try {
      // Try to create a proposal, should fail because it just got removed from the whitelist
      await vanillaAuthenticator.invoke('execute', {
        target: spaceAddress,
        function_selector: BigInt(getSelectorFromName('propose')),
        calldata: proposeCalldata1,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Invalid executor');
    }
  });

  it('The controller can add two executors', async () => {
    await controller.invoke(space, 'add_executors', {
      to_add: [BigInt(zodiacRelayer.address), BigInt(vanillaExecutionStrategy.address)],
    });

    await vanillaAuthenticator.invoke('execute', {
      target: spaceAddress,
      function_selector: BigInt(getSelectorFromName('propose')),
      calldata: proposeCalldata2,
    });
  });
});
