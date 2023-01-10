import { expect } from 'chai';
import { Contract } from 'ethers';
import { starknet, ethers } from 'hardhat';
import { utils } from '@snapshot-labs/sx';
import { zodiacRelayerSetup } from '../shared/setup';
import { StarknetContract, Account } from 'hardhat/types';
import { PROPOSE_SELECTOR } from '../shared/constants';
import { declareAndDeployContract } from '../utils/deploy';

describe('Execution Strategy Whitelist testing', () => {
  // Contracts
  let space: StarknetContract;
  let controller: Account;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let zodiacRelayer: StarknetContract;
  let zodiacModule: Contract;
  let vanillaExecutionStrategy: StarknetContract;

  // Proposal creation parameters
  let spaceAddress: string;
  let executionHash: string;
  let metadataUri: utils.intsSequence.IntsSequence;
  let proposerEthAddress: string;
  let usedVotingStrategies1: string[];
  let userVotingParamsAll1: string[][];
  let executionStrategy1: string;
  let executionParams1: string[];
  let proposeCalldata1: string[];

  // Alternative execution strategy parameters
  let executionStrategy2: string;
  let executionParams2: string[];
  let proposeCalldata2: string[];

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

    vanillaExecutionStrategy = await declareAndDeployContract(
      './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
    );

    spaceAddress = space.address;
    metadataUri = utils.intsSequence.IntsSequence.LEFromString(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    proposerEthAddress = ethers.Wallet.createRandom().address;
    usedVotingStrategies1 = ['0x0'];
    userVotingParamsAll1 = [[]];
    executionStrategy1 = zodiacRelayer.address;
    executionHash = utils.bytes.bytesToHex(ethers.utils.randomBytes(32)); // Random 32 byte hash
    executionParams1 = [
      zodiacModule.address,
      utils.splitUint256.SplitUint256.fromHex(executionHash).low,
      utils.splitUint256.SplitUint256.fromHex(executionHash).high,
    ];
    proposeCalldata1 = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      executionStrategy1,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams1
    );

    executionStrategy2 = vanillaExecutionStrategy.address;
    executionParams2 = [];
    proposeCalldata2 = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      executionStrategy2,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams2
    );
  });

  it('Should create a proposal for a whitelisted execution strategy', async () => {
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: spaceAddress,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata1,
    });

    // Cancel the proposal to be able to add / remove execution_strategies later on
    await controller.invoke(space, 'cancelProposal', {
      proposal_id: 1,
      execution_params: executionParams1,
    });
  }).timeout(1000000);

  it('Should not be able to create a proposal with a non whitelisted execution strategy', async () => {
    try {
      // proposeCalldata2 contains the vanilla execution strategy which is not whitelisted initially
      await controller.invoke(vanillaAuthenticator, 'authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata2,
      });
      throw { message: 'proposal created with non whitelisted execution strategy' };
    } catch (err: any) {
      expect(err.message).to.contain('Voting: Invalid execution strategy');
    }
  }).timeout(1000000);

  it('The controller can whitelist an execution strategy', async () => {
    await controller.invoke(space, 'addExecutionStrategies', {
      addresses: [BigInt(vanillaExecutionStrategy.address)],
    });

    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: spaceAddress,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata2,
    });

    // Cancel the proposal to be able to add / remove execution_strategies later on
    await controller.invoke(space, 'cancelProposal', {
      proposal_id: 2,
      execution_params: executionParams2,
    });
  }).timeout(1000000);

  it('The controller can remove two execution strategies', async () => {
    await controller.invoke(space, 'removeExecutionStrategies', {
      addresses: [BigInt(zodiacRelayer.address), BigInt(vanillaExecutionStrategy.address)],
    });

    try {
      // Try to create a proposal, should fail because it just got removed from the whitelist
      await controller.invoke(vanillaAuthenticator, 'authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata1,
      });
      throw { message: 'proposal not removed from whitelist' };
    } catch (err: any) {
      expect(err.message).to.contain('Voting: Invalid execution strategy');
    }
  }).timeout(1000000);

  it('The controller can add two execution strategies', async () => {
    await controller.invoke(space, 'addExecutionStrategies', {
      addresses: [BigInt(zodiacRelayer.address), BigInt(vanillaExecutionStrategy.address)],
    });

    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: spaceAddress,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata2,
    });
  }).timeout(1000000);
});
