import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { vanillaSetup } from '../shared/setup';
import { StarknetContract, Account } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { getProposeCalldata, getVoteCalldata } from '@snapshot-labs/sx/dist/utils/encoding';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';

describe('Controller Actions', () => {
  let space: StarknetContract;
  let controller: Account;
  let user: Account;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaAuthenticator: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;
  let proposalId: bigint;

  before(async function () {
    this.timeout(800000);
    ({ space, controller, vanillaAuthenticator, vanillaVotingStrategy, vanillaExecutionStrategy } =
      await vanillaSetup());
    user = await starknet.deployAccount('OpenZeppelin');
    proposalId = BigInt(1);
  });

  it('The controller can update the controller', async () => {
    await controller.invoke(space, 'update_controller', {
      new_controller: user.starknetContract.address,
    });

    // Try to update the controler with the previous account
    try {
      await controller.invoke(space, 'update_controller', {
        new_controller: user.starknetContract.address,
      });
      throw { message: 'updated controller`' };
    } catch (error: any) {
      expect(error.message).to.contain('Ownable: caller is not the owner');
    }

    // Now updating again with the previous controller
    await user.invoke(space, 'update_controller', {
      new_controller: controller.starknetContract.address,
    });
  }).timeout(600000);

  it('The controller can add and remove voting strategies', async () => {
    const address = ethers.Wallet.createRandom().address;

    const power = utils.splitUint256.SplitUint256.fromUint(BigInt('1000'));

    const whitelistFactory = await starknet.getContractFactory(
      './contracts/starknet/VotingStrategies/Whitelist.cairo'
    );
    const whitelistStrategy = await whitelistFactory.deploy({
      _whitelist: [address, power.low, power.high],
    });
    const votingStrategyParams: string[][] = [[]];
    const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);

    // Add the whitelist strategy, which will be placed at index 1
    await controller.invoke(space, 'add_voting_strategies', {
      addresses: [whitelistStrategy.address],
      params_flat: votingStrategyParamsFlat,
    });

    // Remove the vanilla voting strategy, which is at index 0
    await controller.invoke(space, 'remove_voting_strategies', {
      indexes: ['0x0'],
    });

    // Ensure that `controller` can't propose (we removed the vanillaVotingStrategy)
    try {
      const wrongProposeCalldata = getProposeCalldata(
        controller.address,
        utils.intsSequence.IntsSequence.LEFromString(''),
        vanillaExecutionStrategy.address,
        ['0x0'],
        [[]],
        []
      );
      await controller.invoke(vanillaAuthenticator, 'authenticate', {
        target: space.address,
        function_selector: PROPOSE_SELECTOR,
        calldata: wrongProposeCalldata,
      });
      throw { message: "voting strategy wasn't removed" };
    } catch (error: any) {
      expect(error.message).to.contain('Invalid voting strategy');
    }

    // Ensure that `address` can propose (we added the whitelist strategy)
    const correctProposeCalldata = getProposeCalldata(
      address,
      utils.intsSequence.IntsSequence.LEFromString(''),
      vanillaExecutionStrategy.address,
      ['0x1'],
      [[]],
      []
    );
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: space.address,
      function_selector: PROPOSE_SELECTOR,
      calldata: correctProposeCalldata,
    });

    // Ensure proposal exists (will throw if proposal id does not exist)
    await space.call('get_proposal_info', {
      proposal_id: proposalId,
    });

    // Cancel the proposal
    await controller.invoke(space, 'cancel_proposal', {
      proposal_id: proposalId,
      execution_params: [],
    });

    // Re-add vanilla voting strategy, which will now be at index 2
    await controller.invoke(space, 'add_voting_strategies', {
      addresses: [vanillaVotingStrategy.address],
      params_flat: votingStrategyParamsFlat,
    });

    // Remove the whitelist voting strategy
    await controller.invoke(space, 'remove_voting_strategies', {
      indexes: ['0x1'],
    });

    proposalId += BigInt(1);
  }).timeout(600000);

  it('The controller can add and remove authenticators', async () => {
    const starknetTxAuthenticatorFactory = await starknet.getContractFactory(
      './contracts/starknet/Authenticators/StarkTx.cairo'
    );
    const starknetTxAuth = (await starknetTxAuthenticatorFactory.deploy()) as StarknetContract;

    // Add the StarknetTx auth
    await controller.invoke(space, 'add_authenticators', {
      addresses: [starknetTxAuth.address],
    });

    // Remove the Vanilla Auth
    await controller.invoke(space, 'remove_authenticators', {
      addresses: [vanillaAuthenticator.address],
    });

    const proposeCalldata = getProposeCalldata(
      user.address,
      utils.intsSequence.IntsSequence.LEFromString(''),
      vanillaExecutionStrategy.address,
      ['0x2'],
      [[]],
      []
    );
    // Ensure that `controller` can't propose (we removed the vanillaAuth)
    try {
      await controller.invoke(vanillaAuthenticator, 'authenticate', {
        target: space.address,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata,
      });
      throw { message: "authenticator wasn't removed" };
    } catch (error: any) {
      expect(error.message).to.contain('Invalid authenticator');
    }

    // Ensure that `address` can propose (we added the StarknetTxAuth)
    await user.invoke(starknetTxAuth, 'authenticate', {
      target: space.address,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata,
    });

    // Cancel the proposal
    await controller.invoke(space, 'cancel_proposal', {
      proposal_id: proposalId,
      execution_params: [],
    });

    // Reset to initial auths
    await controller.invoke(space, 'add_authenticators', {
      addresses: [vanillaAuthenticator.address],
    });
    await controller.invoke(space, 'remove_authenticators', {
      addresses: [starknetTxAuth.address],
    });

    proposalId += BigInt(1);
  }).timeout(600000);

  it('The controller can add and remove execution strategies', async () => {
    const randomExecutionContractFactory = await starknet.getContractFactory(
      './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
    );
    const randomExecutionContract =
      (await randomExecutionContractFactory.deploy()) as StarknetContract;

    // Add a random executor
    await controller.invoke(space, 'add_execution_strategies', {
      addresses: [randomExecutionContract.address],
    });
    // Remove the vanilla executor
    await controller.invoke(space, 'remove_execution_strategies', {
      addresses: [vanillaExecutionStrategy.address],
    });

    const incorrectProposeCalldata = getProposeCalldata(
      user.address,
      utils.intsSequence.IntsSequence.LEFromString(''),
      vanillaExecutionStrategy.address,
      ['0x2'],
      [[]],
      []
    );
    // Ensure that `vanillaExecutionStrategy` is not valid anymore
    try {
      await controller.invoke(vanillaAuthenticator, 'authenticate', {
        target: space.address,
        function_selector: PROPOSE_SELECTOR,
        calldata: incorrectProposeCalldata,
      });
      throw { message: "execution strategy wasn't removed" };
    } catch (error: any) {
      expect(error.message).to.contain('Invalid executor');
    }

    const correctProposeCalldata = getProposeCalldata(
      user.address,
      utils.intsSequence.IntsSequence.LEFromString(''),
      randomExecutionContract.address,
      ['0x2'],
      [[]],
      []
    );
    // Ensure that `randomExecutionContract` is a valid executor
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: space.address,
      function_selector: PROPOSE_SELECTOR,
      calldata: correctProposeCalldata,
    });

    // Cancel the proposal
    await controller.invoke(space, 'cancel_proposal', {
      proposal_id: proposalId,
      execution_params: [],
    });

    // Revert back to initial executor
    await controller.invoke(space, 'add_execution_strategies', {
      addresses: [vanillaExecutionStrategy.address],
    });
    await controller.invoke(space, 'remove_execution_strategies', {
      addresses: [randomExecutionContract.address],
    });

    proposalId += BigInt(1);
  }).timeout(600000);

  it('The controller can update the quorum', async () => {
    // Update the quorum to `2`
    await controller.invoke(space, 'update_quorum', {
      new_quorum: utils.splitUint256.SplitUint256.fromUint(BigInt(2)),
    });

    const proposeCalldata = getProposeCalldata(
      user.address,
      utils.intsSequence.IntsSequence.LEFromString(''),
      vanillaExecutionStrategy.address,
      ['0x2'],
      [[]],
      []
    );
    // Create a new proposal
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: space.address,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata,
    });

    const userVoteCalldata = getVoteCalldata(
      user.address,
      proposalId.toString(16),
      utils.choice.Choice.FOR,
      ['0x2'],
      [[]]
    );
    // Vote once
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: space.address,
      function_selector: VOTE_SELECTOR,
      calldata: userVoteCalldata,
    });

    // Should not work because quorum is set to `2` and only 1 vote has been cast
    try {
      await controller.invoke(space, 'finalize_proposal', {
        proposal_id: proposalId,
        execution_params: [],
      });
      throw { message: 'quorum has not been updated' };
    } catch (error: any) {
      expect(error.message).to.contain('Quorum has not been reached');
    }

    const user2VoteCalldata = getVoteCalldata(
      space.address,
      proposalId.toString(16),
      utils.choice.Choice.FOR,
      ['0x2'],
      [[]]
    );
    // Vote a second time
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: space.address,
      function_selector: VOTE_SELECTOR,
      calldata: user2VoteCalldata,
    });

    // Quorum has now been reached so proposal should get finalized
    await controller.invoke(space, 'finalize_proposal', {
      proposal_id: proposalId,
      execution_params: [],
    });

    // Set back quorum to initial value
    await controller.invoke(space, 'update_quorum', {
      new_quorum: utils.splitUint256.SplitUint256.fromUint(BigInt(1)),
    });

    proposalId += BigInt(1);
  }).timeout(600000);

  it('The controller can update the voting delay', async () => {
    // Set the voting delay to 1000
    await controller.invoke(space, 'update_voting_delay', {
      new_delay: BigInt(1000),
    });

    const proposeCalldata = getProposeCalldata(
      user.address,
      utils.intsSequence.IntsSequence.LEFromString(''),
      vanillaExecutionStrategy.address,
      ['0x2'],
      [[]],
      []
    );
    // Create a proposal
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: space.address,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata,
    });

    // Should not work because voting delay has not elapsed
    const userVoteCalldata = getVoteCalldata(
      user.address,
      proposalId.toString(16),
      utils.choice.Choice.FOR,
      ['0x2'],
      [[]]
    );
    try {
      await controller.invoke(vanillaAuthenticator, 'authenticate', {
        target: space.address,
        function_selector: VOTE_SELECTOR,
        calldata: userVoteCalldata,
      });
      throw { message: 'voting delay has not been updated' };
    } catch (error: any) {
      expect(error.message).to.contain('Voting has not started yet');
    }

    // Fast forward to end of voting delay
    await starknet.devnet.increaseTime(1000);

    // Dummy invoke to get to the next block and effectively increase time.
    // We will be able to remove this once hardhat-plugin has a `create_block` method.
    await controller.invoke(vanillaExecutionStrategy, 'execute', {
      proposal_outcome: BigInt(1),
      execution_params: [],
    });

    // Vote should work now
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: space.address,
      function_selector: VOTE_SELECTOR,
      calldata: userVoteCalldata,
    });

    // Finalize proposal
    await controller.invoke(space, 'finalize_proposal', {
      proposal_id: proposalId,
      execution_params: [],
    });

    // Reset back the voting delay
    await controller.invoke(space, 'update_voting_delay', {
      new_delay: BigInt(0),
    });

    proposalId += BigInt(1);
  }).timeout(600000);

  it('The controller can update the min voting duration', async () => {
    // Update the min voting duration
    await controller.invoke(space, 'update_min_voting_duration', {
      new_min_voting_duration: BigInt(1000),
    });

    const proposeCalldata = getProposeCalldata(
      user.address,
      utils.intsSequence.IntsSequence.LEFromString(''),
      vanillaExecutionStrategy.address,
      ['0x2'],
      [[]],
      []
    );
    // Create a proposal
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: space.address,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata,
    });

    const userVoteCalldata = getVoteCalldata(
      user.address,
      proposalId.toString(16),
      utils.choice.Choice.FOR,
      ['0x2'],
      [[]]
    );
    // Cast a vote
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: space.address,
      function_selector: VOTE_SELECTOR,
      calldata: userVoteCalldata,
    });

    // Finalize now should not work because it's too early to finalize
    // with a minimum_voting_duration of 1000 seconds
    try {
      await controller.invoke(space, 'finalize_proposal', {
        proposal_id: proposalId,
        execution_params: [],
      });
      throw { message: 'min voting duration has not been updated' };
    } catch (error: any) {
      expect(error.message).to.contain('Min voting period has not elapsed');
    }

    // Fast forward in time
    await starknet.devnet.increaseTime(1000);

    // Dummy invoke to get to the next block and effectively increase time.
    // We will be able to remove this once hardhat-plugin has a `create_block` method.
    await controller.invoke(vanillaExecutionStrategy, 'execute', {
      proposal_outcome: BigInt(1),
      execution_params: [],
    });

    // Finalize proposal should work now that we've fast forwarded in time
    await controller.invoke(space, 'finalize_proposal', {
      proposal_id: proposalId,
      execution_params: [],
    });

    // Reset back min voting setting
    await controller.invoke(space, 'update_min_voting_duration', {
      new_min_voting_duration: BigInt(0),
    });

    proposalId += BigInt(1);
  }).timeout(600000);

  it('The controller can update the max voting duration', async () => {
    // Set new max voting duration
    await controller.invoke(space, 'update_max_voting_duration', {
      new_max_voting_duration: BigInt(100),
    });

    const proposeCalldata = getProposeCalldata(
      user.address,
      utils.intsSequence.IntsSequence.LEFromString(''),
      vanillaExecutionStrategy.address,
      ['0x2'],
      [[]],
      []
    );
    // Create a new proposal
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: space.address,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata,
    });

    const userVoteCalldata = getVoteCalldata(
      user.address,
      proposalId.toString(16),
      utils.choice.Choice.FOR,
      ['0x2'],
      [[]]
    );
    // Cast a vote before the end of the vote
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: space.address,
      function_selector: VOTE_SELECTOR,
      calldata: userVoteCalldata,
    });

    // Fast forward to end of voting delay
    await starknet.devnet.increaseTime(100);

    // Dummy invoke to get to the next block and effectively increase time.
    // We will be able to remove this once hardhat-plugin has a `create_block` method.
    await controller.invoke(vanillaExecutionStrategy, 'execute', {
      proposal_outcome: BigInt(1),
      execution_params: [],
    });

    // Should fail because casting a vote once the max_voting_duration has elapsed
    try {
      const spaceVoteCalldata = getVoteCalldata(
        space.address,
        proposalId.toString(16),
        utils.choice.Choice.FOR,
        ['0x2'],
        [[]]
      );
      await controller.invoke(vanillaAuthenticator, 'authenticate', {
        target: space.address,
        function_selector: VOTE_SELECTOR,
        calldata: spaceVoteCalldata,
      });
      throw { message: 'max voting duration has not been updated' };
    } catch (error: any) {
      expect(error.message).to.contain('Voting period has ended');
    }

    await controller.invoke(space, 'finalize_proposal', {
      proposal_id: proposalId,
      execution_params: [],
    });

    // Reset to the inital max voting delay
    await controller.invoke(space, 'update_max_voting_duration', {
      new_max_voting_duration: BigInt(2000),
    });
  }).timeout(600000);

  it('The controller can update the proposal threshold', async () => {
    await controller.invoke(space, 'update_proposal_threshold', {
      new_proposal_threshold: utils.splitUint256.SplitUint256.fromUint(BigInt('0x100')),
    });

    // Change the voting strategy to a whitelist strategy
    // Used to have specific amounts of voting power for specific addresses
    const whitelistFactory = await starknet.getContractFactory(
      './contracts/starknet/VotingStrategies/Whitelist.cairo'
    );
    // space should not have enough VP to reach threshold
    const spaceVotingPower = utils.splitUint256.SplitUint256.fromHex('0x1');
    // user should have enough VP to reach threshold
    const userVotingPower = utils.splitUint256.SplitUint256.fromHex('0x100');
    const whitelistStrategy = await whitelistFactory.deploy({
      _whitelist: [
        space.address,
        spaceVotingPower.low,
        spaceVotingPower.high,
        user.address,
        userVotingPower.low,
        userVotingPower.high,
      ],
    });

    const votingStrategyParams: string[][] = [[]];
    const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);
    // The whitelist strategy will be at index 3
    await controller.invoke(space, 'add_voting_strategies', {
      addresses: [whitelistStrategy.address],
      params_flat: votingStrategyParamsFlat,
    });

    // Should fail because `space` does not have enough VP to reach threshold
    try {
      const spaceProposeCalldata = getProposeCalldata(
        space.address,
        utils.intsSequence.IntsSequence.LEFromString(''),
        vanillaExecutionStrategy.address,
        ['0x3'],
        [[]],
        []
      );
      await controller.invoke(vanillaAuthenticator, 'authenticate', {
        target: space.address,
        function_selector: PROPOSE_SELECTOR,
        calldata: spaceProposeCalldata,
      });
      throw { message: 'proposal threshold not checked properly' };
    } catch (error: any) {
      expect(error.message).to.contain('Not enough voting power');
    }

    const userProposeCalldata = getProposeCalldata(
      user.address,
      utils.intsSequence.IntsSequence.LEFromString(''),
      vanillaExecutionStrategy.address,
      ['0x3'],
      [[]],
      []
    );
    // Should work because `user` has enough VP to reach threshold
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: space.address,
      function_selector: PROPOSE_SELECTOR,
      calldata: userProposeCalldata,
    });

    // Ensure proposal exists
    await space.call('get_proposal_info', {
      proposal_id: proposalId,
    });
  }).timeout(600000);

  it('The controller can update the metadata uri', async () => {
    const newMetadataUri =
      'Snapshot X Test Space 2 blah blah blah blah blah blah blah blah blah blah blah blah';
    const txHash = await controller.invoke(space, 'update_metadata_uri', {
      new_metadata_uri: utils.strings.strToShortStringArr(newMetadataUri),
    });
    const receipt = await starknet.getTransactionReceipt(txHash);
    const decodedEvents = await space.decodeEvents(receipt.events);
    expect(newMetadataUri).to.deep.equal(
      utils.strings.shortStringArrToStr(decodedEvents[0].data.new_metadata_uri)
    );
  }).timeout(600000);
});
