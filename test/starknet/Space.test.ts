import { expect } from 'chai';
import { ethers, starknet } from 'hardhat';
import { StarknetContract, Account } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { vanillaSetup } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';
import { Wallet } from 'ethers';

describe('Space Testing', () => {
  // Contracts
  let space: StarknetContract;
  let relayer: Account;
  let controller: Account;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;

  // Proposal creation parameters
  let spaceAddress: string;
  let metadataUri: utils.intsSequence.IntsSequence;
  let proposerEthAddress: string;
  let usedVotingStrategies1: string[];
  let userVotingParamsAll1: string[][];
  let executionStrategy: string;
  let executionParams: string[];
  let proposeCalldata: string[];

  // Additional parameters for voting
  let voterEthAddress: string;
  let proposalId: string;
  let choice: utils.choice.Choice;
  let usedVotingStrategies2: string[];
  let userVotingParamsAll2: string[][];
  let voteCalldata: string[];

  before(async function () {
    this.timeout(800000);
    relayer = await starknet.deployAccount('OpenZeppelin');

    ({ space, controller, vanillaAuthenticator, vanillaVotingStrategy, vanillaExecutionStrategy } =
      await vanillaSetup());

    metadataUri = utils.intsSequence.IntsSequence.LEFromString(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    proposerEthAddress = ethers.Wallet.createRandom().address;
    spaceAddress = space.address;
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

    voterEthAddress = ethers.Wallet.createRandom().address;
    proposalId = '0x1';
    choice = utils.choice.Choice.FOR;
    usedVotingStrategies2 = ['0x0']; // The vanilla voting strategy corresponds to index 0 in the space contract
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
      await relayer.invoke(vanillaAuthenticator, 'authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata,
      });
      const { proposal_info } = await space.call('getProposalInfo', {
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
      await relayer.invoke(vanillaAuthenticator, 'authenticate', {
        target: spaceAddress,
        function_selector: VOTE_SELECTOR,
        calldata: voteCalldata,
      });
      const { proposal_info } = await space.call('getProposalInfo', {
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
      await relayer.invoke(space, 'finalizeProposal', {
        proposal_id: proposalId,
        execution_params: executionParams,
      });
    }
  }).timeout(6000000);

  it('Fails if an invalid voting strategy is used', async () => {
    // -- Creates the proposal --
    try {
      await relayer.invoke(vanillaAuthenticator, 'authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: utils.encoding.getProposeCalldata(
          proposerEthAddress,
          metadataUri,
          executionStrategy,
          ['0x1'],
          userVotingParamsAll1,
          executionParams
        ),
      });
    } catch (error: any) {
      expect(error.message).to.contain('Voting: Invalid voting strategy');
    }
  }).timeout(6000000);

  it('Fails if the same voting strategy is used multiple times', async () => {
    // -- Creates the proposal --
    {
      const duplicateVotingStrategies = [
        vanillaVotingStrategy.address,
        vanillaAuthenticator.address,
        vanillaVotingStrategy.address,
      ];
      const duplicateCalldata = utils.encoding.getProposeCalldata(
        proposerEthAddress,
        metadataUri,
        executionStrategy,
        duplicateVotingStrategies,
        userVotingParamsAll1,
        executionParams
      );

      try {
        await relayer.invoke(vanillaAuthenticator, 'authenticate', {
          target: spaceAddress,
          function_selector: PROPOSE_SELECTOR,
          calldata: duplicateCalldata,
        });
      } catch (error: any) {
        expect(error.message).to.contain('Voting: Duplicate entry found');
      }
    }
  }).timeout(6000000);

  it('Correctly aggregates voting power when using multiple voting strategies', async () => {
    // -- Register 2nd and 3rd voting strategy --
    await controller.invoke(space, 'addVotingStrategies', {
      addresses: [vanillaVotingStrategy.address],
      params_flat: utils.encoding.flatten2DArray([[]]),
    });
    await controller.invoke(space, 'addVotingStrategies', {
      addresses: [vanillaVotingStrategy.address],
      params_flat: utils.encoding.flatten2DArray([[]]),
    });

    // -- Creates the proposal --
    proposeCalldata = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      executionStrategy,
      ['0x0', '0x1', '0x2'],
      [[], [], []],
      executionParams
    );
    await relayer.invoke(vanillaAuthenticator, 'authenticate', {
      target: spaceAddress,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata,
    });

    // -- Casts vote --
    voteCalldata = utils.encoding.getVoteCalldata(
      voterEthAddress,
      '0x2',
      choice,
      ['0x0', '0x1', '0x2'],
      [[], [], []]
    );

    await relayer.invoke(vanillaAuthenticator, 'authenticate', {
      target: spaceAddress,
      function_selector: VOTE_SELECTOR,
      calldata: voteCalldata,
    });

    const { proposal_info } = await space.call('getProposalInfo', {
      proposal_id: '0x2',
    });

    const _for = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_for).toUint();
    expect(_for).to.deep.equal(BigInt(3));
    const against = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_against).toUint();
    expect(against).to.deep.equal(BigInt(0));
    const abstain = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_abstain).toUint();
    expect(abstain).to.deep.equal(BigInt(0));
  }).timeout(6000000);

  it('Fails if quorum has not been reached', async () => {
    // Add a special execution strategy that will fail if the outcome is not `REJECTED`.
    const failsIfRejected = await (
      await starknet.getContractFactory(
        './contracts/starknet/TestContracts/ExecutionStrategies/FailsIfRejected.cairo'
      )
    ).deploy();
    await controller.invoke(space, 'addExecutionStrategies', {
      addresses: [failsIfRejected.address],
    });

    const proposeCallDataWithExec = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      failsIfRejected.address,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );

    // Create the proposal with the new execution strategy
    await relayer.invoke(vanillaAuthenticator, 'authenticate', {
      target: spaceAddress,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCallDataWithExec,
    });

    // Finalizing now should not work because quorum has not been reached
    try {
      await relayer.invoke(space, 'finalizeProposal', {
        proposal_id: 0x3,
        execution_params: executionParams,
      });
    } catch (error: any) {
      expect(error.message).to.contain('Voting: Quorum has not been reached');
    }
  });

  it('Finalizes if quorum has not been reached but max voting duration has elapsed', async () => {
    // Fast forward to the end of the max voting period
    await starknet.devnet.increaseTime(4242);
    // Need to create an empty block if we want the time increase to be effective
    const emptyBlock = await starknet.devnet.createBlock();

    // Finalizing should now work since max voting period has elapsed
    try {
      await relayer.invoke(space, 'finalizeProposal', {
        proposal_id: 0x3,
        execution_params: executionParams,
      });
    } catch (error: any) {
      expect(error.message).to.contain('TestExecutionStrategy: Proposal was rejected');
    }
  });

  it('Reverts when querying an invalid proposal id', async () => {
    try {
      await space.call('getProposalInfo', {
        proposal_id: 42,
      });
    } catch (error: any) {
      expect(error.message).to.contain('Voting: Proposal does not exist');
    }
  }).timeout(6000000);
});
