import { expect } from 'chai';
import { ethers } from 'hardhat';
import { StarknetContract, Account } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { starknetExecutionSetup } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR, AUTHENTICATE_SELECTOR } from '../shared/constants';

describe('Starknet execution via account contract', () => {
  // Contracts
  let space: StarknetContract;
  let controller: Account;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let starknetExecutionStrategy: StarknetContract;

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

  // Calls
  let tx1: utils.encoding.Call;
  let tx2: utils.encoding.Call;
  let tx3: utils.encoding.Call;

  before(async function () {
    this.timeout(800000);

    ({ space, controller, vanillaAuthenticator, vanillaVotingStrategy, starknetExecutionStrategy } =
      await starknetExecutionSetup());

    metadataUri = utils.strings.strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    proposerEthAddress = ethers.Wallet.createRandom().address;
    spaceAddress = BigInt(space.address);
    usedVotingStrategies1 = [BigInt(vanillaVotingStrategy.address)];
    userVotingParamsAll1 = [[]];
    executionStrategy = BigInt(1); // Starknet execution does not use a separate strategy contract, instead its indicated via passing the value 1.

    // For the execution of the proposal, we create 3 new dummy proposals
    const txCalldata1 = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      BigInt(1234),
      usedVotingStrategies1,
      userVotingParamsAll1,
      []
    );
    const txCalldata2 = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      BigInt(4567),
      usedVotingStrategies1,
      userVotingParamsAll1,
      []
    );
    const txCalldata3 = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      BigInt(456789),
      usedVotingStrategies1,
      userVotingParamsAll1,
      []
    );
    tx1 = {
      to: BigInt(vanillaAuthenticator.address),
      functionSelector: AUTHENTICATE_SELECTOR,
      calldata: [spaceAddress, PROPOSE_SELECTOR, BigInt(txCalldata1.length), ...txCalldata1],
    };
    tx2 = {
      to: BigInt(vanillaAuthenticator.address),
      functionSelector: AUTHENTICATE_SELECTOR,
      calldata: [spaceAddress, PROPOSE_SELECTOR, BigInt(txCalldata2.length), ...txCalldata2],
    };
    tx3 = {
      to: BigInt(vanillaAuthenticator.address),
      functionSelector: AUTHENTICATE_SELECTOR,
      calldata: [spaceAddress, PROPOSE_SELECTOR, BigInt(txCalldata3.length), ...txCalldata3],
    };
    executionParams = utils.encoding.createStarknetExecutionParams([tx1, tx2, tx3]);

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
    }
    // -- Casts a vote FOR --
    {
      await vanillaAuthenticator.invoke('authenticate', {
        target: spaceAddress,
        function_selector: VOTE_SELECTOR,
        calldata: voteCalldata,
      });
    }

    // -- Executes the proposal, which should create 3 new dummy proposal in the same space
    {
      await space.invoke('finalize_proposal', {
        proposal_id: proposalId,
        execution_params: executionParams,
      });

      let { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: 2,
      });
      // We can check that the proposal was successfully created by checking the execution strategy
      // as it will be zero if the new proposal was not created
      expect(proposal_info.proposal.executor).to.deep.equal(BigInt(1234));

      // Same for second dummy proposal
      ({ proposal_info } = await space.call('get_proposal_info', {
        proposal_id: 3,
      }));
      expect(proposal_info.proposal.executor).to.deep.equal(BigInt(4567));

      ({ proposal_info } = await space.call('get_proposal_info', {
        proposal_id: 4,
      }));
      expect(proposal_info.proposal.executor).to.deep.equal(BigInt(456789));
    }
  }).timeout(6000000);
});
