import { expect } from 'chai';
import { Contract } from 'ethers';
import { starknet, ethers } from 'hardhat';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { zodiacRelayerSetup } from '../shared/setup';
import { SplitUint256 } from '../shared/types';
import { getProposeCalldata, bytesToHex } from '../shared/helpers';
import { StarknetContract, Account } from 'hardhat/types';
import { PROPOSE_SELECTOR } from '../shared/constants';

describe('Whitelist testing', () => {
  // Contracts
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
  let userVotingParamsAll1: bigint[][];
  let executionStrategy1: bigint;
  let executionParams1: bigint[];
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
    } = await zodiacRelayerSetup());

    const vanillaExecutionStrategyFactory = await starknet.getContractFactory(
      './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
    );
    vanillaExecutionStrategy = await vanillaExecutionStrategyFactory.deploy();

    spaceAddress = BigInt(space.address);

    metadataUri = strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    proposerEthAddress = ethers.Wallet.createRandom().address;
    spaceAddress = BigInt(space.address);
    usedVotingStrategies1 = [BigInt(vanillaVotingStrategy.address)];
    userVotingParamsAll1 = [[]];
    executionStrategy1 = BigInt(zodiacRelayer.address);
    executionHash = bytesToHex(ethers.utils.randomBytes(32)); // Random 32 byte hash
    executionParams1 = [
      BigInt(zodiacModule.address),
      SplitUint256.fromHex(executionHash).low,
      SplitUint256.fromHex(executionHash).high,
    ];
    proposeCalldata1 = getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      executionStrategy1,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams1
    );

    executionStrategy2 = BigInt(vanillaExecutionStrategy.address);
    executionParams2 = [];
    proposeCalldata2 = getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      executionStrategy2,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams2
    );
  });

  it('Should create a proposal for a whitelisted executor', async () => {
    {
      await vanillaAuthenticator.invoke('authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata1,
      });
    }
  }).timeout(1000000);

  it('Should not be able to create a proposal with a non whitelisted executor', async () => {
    try {
      // proposeCalldata2 contains the vanilla execution strategy which is not whitelisted initially
      await vanillaAuthenticator.invoke('authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata2,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Invalid executor');
    }
  }).timeout(1000000);

  it('The Controller can whitelist an executor', async () => {
    await controller.invoke(space, 'add_executors', {
      to_add: [BigInt(vanillaExecutionStrategy.address)],
    });

    await vanillaAuthenticator.invoke('authenticate', {
      target: spaceAddress,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata2,
    });
  }).timeout(1000000);

  it('The controller can remove two executors', async () => {
    await controller.invoke(space, 'remove_executors', {
      to_remove: [BigInt(zodiacRelayer.address), BigInt(vanillaExecutionStrategy.address)],
    });

    try {
      // Try to create a proposal, should fail because it just got removed from the whitelist
      await vanillaAuthenticator.invoke('authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata1,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Invalid executor');
    }
  }).timeout(1000000);

  it('The controller can add two executors', async () => {
    await controller.invoke(space, 'add_executors', {
      to_add: [BigInt(zodiacRelayer.address), BigInt(vanillaExecutionStrategy.address)],
    });

    await vanillaAuthenticator.invoke('authenticate', {
      target: spaceAddress,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata2,
    });
  }).timeout(1000000);
});
