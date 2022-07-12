import { expect } from 'chai';
import { ethers } from 'hardhat';
import { StarknetContract, Account } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { SplitUint256, Choice } from '../shared/types';
import { getProposeCalldata, getVoteCalldata, bytesToHex } from '../shared/helpers';
import { spaceFactorySetup } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';
import { hexToBytes, flatten2DArray } from '../shared/helpers';

describe('Space Deployment Testing', () => {
  // Contracts
  let space: StarknetContract;
  let spaceDeployer: StarknetContract;
  let controller: Account;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;

  // Space deployment parameters
  let votingDelay: bigint;
  let minVotingDuration: bigint;
  let maxVotingDuration: bigint;
  let votingStrategies: bigint[];
  let votingStrategyParamsFlat: bigint[];
  let authenticators: bigint[];
  let executors: bigint[];
  let quorum: SplitUint256;
  let proposalThreshold: SplitUint256;

  // Proposal creation parameters
  let spaceAddress: bigint;
  let executionHash: string;
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
  let choice: Choice;
  let usedVotingStrategies2: bigint[];
  let userVotingParamsAll2: bigint[][];
  let voteCalldata: bigint[];

  before(async function () {
    this.timeout(800000);

    ({
      spaceDeployer,
      controller,
      vanillaAuthenticator,
      vanillaVotingStrategy,
      vanillaExecutionStrategy,
    } = await spaceFactorySetup());

    votingDelay = BigInt(0);
    minVotingDuration = BigInt(0);
    maxVotingDuration = BigInt(2000);
    votingStrategies = [BigInt(vanillaVotingStrategy.address)];
    votingStrategyParamsFlat = flatten2DArray([[]]);
    authenticators = [BigInt(vanillaAuthenticator.address)];
    executors = [BigInt(vanillaExecutionStrategy.address)];
    quorum = SplitUint256.fromUint(BigInt(1)); //  Quorum of one for the vanilla test
    proposalThreshold = SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test
  });

  it('A user should be able to deploy a space contract', async () => {
    await spaceDeployer.invoke('deploy_space', {
      _voting_delay: votingDelay,
      _min_voting_duration: minVotingDuration,
      _max_voting_duration: maxVotingDuration,
      _proposal_threshold: proposalThreshold,
      _controller: BigInt(controller.address),
      _quorum: quorum,
      _voting_strategy_params_flat: votingStrategyParamsFlat,
      _voting_strategies: votingStrategies,
      _authenticators: authenticators,
      _executors: executors,
    });

    executionHash = bytesToHex(ethers.utils.randomBytes(32)); // Random 32 byte hash
    metadataUri = utils.strings.strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    proposerEthAddress = ethers.Wallet.createRandom().address;
    spaceAddress = BigInt(space.address);
    usedVotingStrategies1 = [BigInt(vanillaVotingStrategy.address)];
    userVotingParamsAll1 = [[]];
    executionStrategy = BigInt(vanillaExecutionStrategy.address);
    executionParams = [];
    proposeCalldata = getProposeCalldata(
      proposerEthAddress,
      executionHash,
      metadataUri,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );
  }).timeout(6000000);
});
