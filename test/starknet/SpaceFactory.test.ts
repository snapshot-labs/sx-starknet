import { expect } from 'chai';
import { ethers } from 'hardhat';
import { StarknetContract, Account } from 'hardhat/types';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { SplitUint256, Choice } from '../shared/types';
import { getProposeCalldata, getVoteCalldata, bytesToHex } from '../shared/helpers';
import { spaceFactorySetup } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';

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
  let votingStrategyParams: bigint[][];
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

    ({ spaceDeployer, controller, vanillaAuthenticator, vanillaVotingStrategy, vanillaExecutionStrategy } =
      await spaceFactorySetup());

      const votingDelay = BigInt(0);
      const minVotingDuration = BigInt(0);
      const maxVotingDuration = BigInt(2000);
      const votingStrategies: bigint[] = [BigInt(vanillaVotingStrategy.address)];
      const votingStrategyParams: bigint[][] = [[]]; // No params for the vanilla voting strategy
      const votingStrategyParamsFlat: bigint[] = flatten2DArray(votingStrategyParams);
      const authenticators: bigint[] = [BigInt(vanillaAuthenticator.address)];
      const executors: bigint[] = [BigInt(vanillaExecutionStrategy.address)];
      const quorum: SplitUint256 = SplitUint256.fromUint(BigInt(1)); //  Quorum of one for the vanilla test
      const proposalThreshold: SplitUint256 = SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  });

  it('A user should be able to deploy a space contract', async () => {




    await spaceDeployer.invoke('deploy_space', {})


  }).timeout(6000000);
});
