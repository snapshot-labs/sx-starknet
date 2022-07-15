import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { StarknetContract, Account } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';

async function vanillaSetup() {
  // We make the space controller public key the same as the public key of the space account itself
  const controller = (await starknet.deployAccount('OpenZeppelin', {
    privateKey: '0x1',
  })) as Account;
  console.log(controller.publicKey);
  const spaceFactory = await starknet.getContractFactory('./contracts/starknet/SXBase.cairo');
  const vanillaVotingStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const vanillaAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/Authenticators/Vanilla.cairo'
  );
  const vanillaExecutionStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  const deployments = [
    vanillaAuthenticatorFactory.deploy(),
    vanillaVotingStrategyFactory.deploy(),
    vanillaExecutionStrategyFactory.deploy(),
  ];
  const contracts = await Promise.all(deployments);
  const vanillaAuthenticator = contracts[0] as StarknetContract;
  const vanillaVotingStrategy = contracts[1] as StarknetContract;
  const vanillaExecutionStrategy = contracts[2] as StarknetContract;

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: bigint[] = [BigInt(vanillaVotingStrategy.address)];
  const votingStrategyParams: bigint[][] = [[]]; // No params for the vanilla voting strategy
  const votingStrategyParamsFlat: bigint[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: bigint[] = [BigInt(vanillaAuthenticator.address)];
  const executors: bigint[] = [BigInt(vanillaExecutionStrategy.address)];
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  console.log('Deploying space contract...');
  const space = (await spaceFactory.deploy({
    public_key: BigInt(controller.publicKey),
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: BigInt(controller.starknetContract.address),
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    executors: executors,
  })) as StarknetContract;
  console.log('deployed!');

  return {
    space,
    controller,
    vanillaAuthenticator,
    vanillaVotingStrategy,
    vanillaExecutionStrategy,
  };
}

describe('Space Testing', () => {
  // Contracts
  let space: StarknetContract;
  let controller: Account;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;

  // Proposal creation parameters
  let spaceAddress: bigint;
  let metadataUri: bigint[];
  let proposerEthAddress: string;
  let usedVotingStrategies1: bigint[];
  let userVotingParamsAll1: bigint[][];
  let executionStrategy: bigint;
  let executionParams: bigint[];
  let proposeCalldata: bigint[];

  // Additional parameters for voting
  let voterEthAddress: string;
  let proposalId: bigint;
  let choice: utils.choice.Choice;
  let usedVotingStrategies2: bigint[];
  let userVotingParamsAll2: bigint[][];
  let voteCalldata: bigint[];

  before(async function () {
    this.timeout(800000);

    ({ space, controller, vanillaAuthenticator, vanillaVotingStrategy, vanillaExecutionStrategy } =
      await vanillaSetup());

    metadataUri = utils.strings.strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    proposerEthAddress = ethers.Wallet.createRandom().address;
    spaceAddress = BigInt(space.address);
    usedVotingStrategies1 = [BigInt(vanillaVotingStrategy.address)];
    userVotingParamsAll1 = [[]];
    executionStrategy = BigInt(vanillaExecutionStrategy.address);
    executionParams = [];
    proposeCalldata = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );

    voterEthAddress = ethers.Wallet.createRandom().address;
    proposalId = BigInt(1);
    choice = utils.choice.Choice.FOR;
    usedVotingStrategies2 = [BigInt(vanillaVotingStrategy.address)];
    userVotingParamsAll2 = [[]];
    voteCalldata = utils.encoding.getVoteCalldata(
      voterEthAddress,
      proposalId,
      choice,
      usedVotingStrategies2,
      userVotingParamsAll2
    );
  });

  it('Users should be able to create a proposal, cast a vote, and execute it', async () => {
    // -- Creates the proposal --
    {
      await vanillaAuthenticator.invoke('authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata,
      });

      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      const _for = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(0));
      const against = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));
    }
    // -- Casts a vote FOR --
    {
      await vanillaAuthenticator.invoke('authenticate', {
        target: spaceAddress,
        function_selector: VOTE_SELECTOR,
        calldata: voteCalldata,
      });

      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      const _for = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(1));
      const against = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));
    }

    // -- Executes the proposal --
    {
      await space.invoke('finalize_proposal', {
        proposal_id: proposalId,
        execution_params: executionParams,
      });
    }
  }).timeout(6000000);
});
