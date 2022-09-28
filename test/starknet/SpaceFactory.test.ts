import { expect } from 'chai';
import { ethers, starknet } from 'hardhat';
import { StarknetContract, Account, StarknetContractFactory } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { spaceFactorySetup } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';

describe('Space Deployment Testing', () => {
  // Contracts
  let space: StarknetContract;
  let spaceFactoryClass: StarknetContractFactory;
  let spaceDeployer: StarknetContract;
  let controller: Account;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;

  // Space deployment parameters
  let votingDelay: bigint;
  let minVotingDuration: bigint;
  let maxVotingDuration: bigint;
  let votingStrategies: string[];
  let votingStrategyParamsFlat: string[];
  let authenticators: string[];
  let executors: string[];
  let quorum: utils.splitUint256.SplitUint256;
  let proposalThreshold: utils.splitUint256.SplitUint256;
  let spaceMetadataUri: string;

  // Proposal creation parameters
  let spaceAddress: bigint;
  let metadataUri: utils.intsSequence.IntsSequence;
  let proposerEthAddress: string;
  let usedVotingStrategies1: string[];
  let userVotingParamsAll1: string[][];
  let executionStrategy: string;
  let executionParams: string[];
  let proposeCalldata: string[];

  before(async function () {
    this.timeout(800000);

    ({
      spaceDeployer,
      spaceFactoryClass,
      controller,
      vanillaAuthenticator,
      vanillaVotingStrategy,
      vanillaExecutionStrategy,
    } = await spaceFactorySetup());

    votingDelay = BigInt(0);
    minVotingDuration = BigInt(0);
    maxVotingDuration = BigInt(2000);
    votingStrategies = [vanillaVotingStrategy.address];
    votingStrategyParamsFlat = utils.encoding.flatten2DArray([[]]);
    authenticators = [vanillaAuthenticator.address];
    executors = [vanillaExecutionStrategy.address];
    quorum = utils.splitUint256.SplitUint256.fromUint(BigInt(1)); //  Quorum of one for the vanilla test
    proposalThreshold = utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test
    spaceMetadataUri = 'SnapshotXTestSpace';
  });

  it('A user should be able to deploy a space contract', async () => {
    const txHash = await controller.invoke(spaceDeployer, 'deploy_space', {
      public_key: BigInt(controller.publicKey),
      voting_delay: votingDelay,
      min_voting_duration: minVotingDuration,
      max_voting_duration: maxVotingDuration,
      proposal_threshold: proposalThreshold,
      controller: BigInt(controller.address),
      quorum: quorum,
      voting_strategy_params_flat: votingStrategyParamsFlat,
      voting_strategies: votingStrategies,
      authenticators: authenticators,
      executors: executors,
      metadata_uri: utils.strings.strToShortStringArr(spaceMetadataUri),
    });
    const receipt = await starknet.getTransactionReceipt(txHash);
    // Removing first event as that's from the account contract deployment
    const decodedEvents = await spaceDeployer.decodeEvents(receipt.events.slice(1));
    metadataUri = utils.intsSequence.IntsSequence.LEFromString(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    proposerEthAddress = ethers.Wallet.createRandom().address;
    spaceAddress = decodedEvents[0].data.space_address;
    space = spaceFactoryClass.getContractAt(`0x${spaceAddress.toString(16)}`);
    usedVotingStrategies1 = ['0x0'];
    userVotingParamsAll1 = [[]];
    executionStrategy = vanillaExecutionStrategy.address;
    executionParams = [];
    proposeCalldata = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );

    // -- Creates the proposal --
    {
      await controller.invoke(vanillaAuthenticator, 'authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata,
      });

      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: '0x1',
      });

      const _for = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(0));
      const against = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));
    }
  }).timeout(6000000);
});
