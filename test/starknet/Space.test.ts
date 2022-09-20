import { expect } from 'chai';
import { ethers, starknet } from 'hardhat';
import { StarknetContract, Account } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { vanillaSetup } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';

describe('Space Testing', () => {
  // Contracts
  let space: StarknetContract;
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
    const wallet = starknet.getWallet('OpenZeppelin');
    console.log(wallet);
    // -- Creates the proposal --
    {
      console.log(PROPOSE_SELECTOR);
      console.log(spaceAddress);
      await vanillaAuthenticator.invoke(
        'authenticate',
        {
          target: spaceAddress,
          function_selector: PROPOSE_SELECTOR,
          calldata: proposeCalldata,
        },
        { wallet }
      );

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
      await vanillaAuthenticator.invoke(
        'authenticate',
        {
          target: spaceAddress,
          function_selector: VOTE_SELECTOR,
          calldata: voteCalldata,
        },
        { wallet }
      );
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

  // it('Fails if an invalid voting strategy is used', async () => {
  //   // -- Creates the proposal --
  //   try {
  //     await vanillaAuthenticator.invoke('authenticate', {
  //       target: spaceAddress,
  //       function_selector: PROPOSE_SELECTOR,
  //       calldata: utils.encoding.getProposeCalldata(
  //         proposerEthAddress,
  //         metadataUri,
  //         executionStrategy,
  //         ['0x1'],
  //         userVotingParamsAll1,
  //         executionParams
  //       ),
  //     });
  //   } catch (error: any) {
  //     expect(error.message).to.contain('Invalid voting strategy');
  //   }
  // }).timeout(6000000);

  // it('Fails if the same voting strategy is used multiple times', async () => {
  //   // -- Creates the proposal --
  //   {
  //     const duplicateVotingStrategies = [
  //       vanillaVotingStrategy.address,
  //       vanillaAuthenticator.address,
  //       vanillaVotingStrategy.address,
  //     ];
  //     const duplicateCalldata = utils.encoding.getProposeCalldata(
  //       proposerEthAddress,
  //       metadataUri,
  //       executionStrategy,
  //       duplicateVotingStrategies,
  //       userVotingParamsAll1,
  //       executionParams
  //     );

  //     try {
  //       await vanillaAuthenticator.invoke('authenticate', {
  //         target: spaceAddress,
  //         function_selector: PROPOSE_SELECTOR,
  //         calldata: duplicateCalldata,
  //       });
  //     } catch (error: any) {
  //       expect(error.message).to.contain('Duplicate entry found');
  //     }
  //   }
  // }).timeout(6000000);

  // it('Correctly aggregates voting power when using multiple voting strategies', async () => {
  //   // -- Register 2nd and 3rd voting strategy --
  //   await controller.invoke(space, 'add_voting_strategies', {
  //     addresses: [vanillaVotingStrategy.address],
  //     params_flat: utils.encoding.flatten2DArray([[]]),
  //   });
  //   await controller.invoke(space, 'add_voting_strategies', {
  //     addresses: [vanillaVotingStrategy.address],
  //     params_flat: utils.encoding.flatten2DArray([[]]),
  //   });

  //   // -- Creates the proposal --
  //   proposeCalldata = utils.encoding.getProposeCalldata(
  //     proposerEthAddress,
  //     metadataUri,
  //     executionStrategy,
  //     ['0x0', '0x1', '0x2'],
  //     [[], [], []],
  //     executionParams
  //   );
  //   await vanillaAuthenticator.invoke('authenticate', {
  //     target: spaceAddress,
  //     function_selector: PROPOSE_SELECTOR,
  //     calldata: proposeCalldata,
  //   });

  //   // -- Casts vote --
  //   voteCalldata = utils.encoding.getVoteCalldata(
  //     voterEthAddress,
  //     '0x2',
  //     choice,
  //     ['0x0', '0x1', '0x2'],
  //     [[], [], []]
  //   );

  //   await vanillaAuthenticator.invoke('authenticate', {
  //     target: spaceAddress,
  //     function_selector: VOTE_SELECTOR,
  //     calldata: voteCalldata,
  //   });

  //   const { proposal_info } = await space.call('get_proposal_info', {
  //     proposal_id: '0x2',
  //   });

  //   const _for = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_for).toUint();
  //   expect(_for).to.deep.equal(BigInt(3));
  //   const against = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_against).toUint();
  //   expect(against).to.deep.equal(BigInt(0));
  //   const abstain = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_abstain).toUint();
  //   expect(abstain).to.deep.equal(BigInt(0));
  // }).timeout(6000000);

  // it('Reverts when querying an invalid proposal id', async () => {
  //   try {
  //     await space.call('get_proposal_info', {
  //       proposal_id: 3,
  //     });
  //   } catch (error: any) {
  //     expect(error.message).to.contain('Proposal does not exist');
  //   }
  // }).timeout(6000000);
});
