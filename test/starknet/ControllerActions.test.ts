import { expect } from 'chai';
import { starknet } from 'hardhat';
import { vanillaSetup } from '../shared/setup';
import { StarknetContract, Account } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';

describe('Controller Actions', () => {
  let space: StarknetContract;
  let controller: Account;
  let user: Account;

  before(async function () {
    this.timeout(800000);
    ({ space, controller } = await vanillaSetup());
    user = await starknet.deployAccount('OpenZeppelin');
  });

  it('The controller can update the controller', async () => {
    await controller.invoke(space, 'update_controller', {
      new_controller: user.starknetContract.address,
    });

    // Now updating again with the new controller
    await user.invoke(space, 'update_controller', {
      new_controller: controller.starknetContract.address,
    });
  }).timeout(600000);

  it('Other accounts cannot update the controller', async () => {
    try {
      await user.invoke(space, 'update_controller', {
        new_controller: user.starknetContract.address,
      });
    } catch (error: any) {
      expect(error.message).to.contain('Ownable: caller is not the owner');
    }
  }).timeout(600000);

  it('The controller can add and remove voting strategies', async () => {
    const address = ethers.Wallet.createRandom().address;

    const power = utils.splitUint256.SplitUint256.fromUint(BigInt('1000'));

    const whitelistFactory = await starknet.getContractFactory(
      './contracts/starknet/VotingStrategies/Whitelist.cairo'
    );
    const whitelistStrategy = await whitelistFactory.deploy({
      _whitelist: [
        address,
        power.low,
        power.high,
      ],
    });
    const votingStrategyParams: string[][] = [[]];
    const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);
    // Add the whitelist strategy
    await controller.invoke(space, 'add_voting_strategies', {
      to_add: [whitelistStrategy.address],
      params_flat: votingStrategyParamsFlat,
    });

    // Remove the vanilla voting strategy
    await controller.invoke(space, 'remove_voting_strategies', {
      to_remove: [vanillaVotingStrategy.address],
    });

    // Ensure that `controller` can't propose (we removed the vanillaVotingStrategy)
    try {
      const wrongProposeCalldata = getProposeCalldata(controller.address, utils.intsSequence.IntsSequence.LEFromString(""), vanillaExecutionStrategy.address, [vanillaVotingStrategy.address], [[]], []);
      await controller.invoke(vanillaAuthenticator, "authenticate", {
        target: space.address,
        function_selector: PROPOSE_SELECTOR,
        calldata: wrongProposeCalldata,
      });
    } catch (error: any) {
      expect(error.message).to.contain('Invalid voting strategy');
    }

    // Ensure that `address` can propose (we added the whitelist strategy)
    const correctProposeCalldata = getProposeCalldata(address, utils.intsSequence.IntsSequence.LEFromString(""), vanillaExecutionStrategy.address, [whitelistStrategy.address], [[]], []);
    await controller.invoke(vanillaAuthenticator, "authenticate", {
      target: space.address,
      function_selector: PROPOSE_SELECTOR,
      calldata: correctProposeCalldata,
    });

    // Ensure proposal exists (will throw if proposal id does not exist)
    await space.call("get_proposal_info", {
      proposal_id: 1,
    });

    // Cancel the proposal
    await controller.invoke(space, "cancel_proposal", {
      proposal_id: 1,
      execution_params: [],
    });

    // Put back the original strategy
    await controller.invoke(space, 'add_voting_strategies', {
      to_add: [vanillaVotingStrategy.address],
      params_flat: votingStrategyParamsFlat,
    });
    
    // Remove the vanilla voting strategy
    await controller.invoke(space, 'remove_voting_strategies', {
      to_remove: [whitelistStrategy.address],
    });
  }).timeout(600000);

  it('The controller can add and remove authenticators', async () => {
    const starknetTxAuthenticatorFactory = await starknet.getContractFactory(
      './contracts/starknet/Authenticators/StarkTx.cairo'
    );
    const starknetTxAuth = await starknetTxAuthenticatorFactory.deploy() as StarknetContract;

    // Add the StarknetTx auth
    await controller.invoke(space, 'add_authenticators', {
      to_add: [starknetTxAuth.address],
    });

    // Remove the Vanilla Auth
    await controller.invoke(space, 'remove_authenticators', {
      to_remove: [vanillaAuthenticator.address],
    });

    const proposeCalldata = getProposeCalldata(user.address, utils.intsSequence.IntsSequence.LEFromString(""), vanillaExecutionStrategy.address, [vanillaVotingStrategy.address], [[]], []);
    // Ensure that `controller` can't propose (we removed the vanillaAuth)
    try {
      await controller.invoke(vanillaAuthenticator, "authenticate", {
        target: space.address,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata,
      });
    } catch (error: any) {
      expect(error.message).to.contain('Invalid authenticator');
    }

    // Ensure that `address` can propose (we added the StarknetTxAuth)
    await user.invoke(starknetTxAuth, "authenticate", {
      target: space.address,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata,
    });

    // Ensure proposal exists (will throw if proposal id does not exist)
    const { proposal_info } =  await space.call("get_proposal_info", {
      proposal_id: 1,
    });
  }).timeout(600000);

  it('The controller can add and remove execution strategies', async () => {
    const executionStrategies: bigint[] = [BigInt(1234), BigInt(4567)];
    await controller.invoke(space, 'add_executors', {
      to_add: executionStrategies,
    });
    await controller.invoke(space, 'remove_executors', {
      to_remove: executionStrategies,
    });
  }).timeout(600000);

  it('The controller can update the quorum', async () => {
    await controller.invoke(space, 'update_quorum', {
      new_quorum: SplitUint256.fromUint(BigInt(1234)),
    });
  }).timeout(600000);

  it('The controller can update the voting delay', async () => {
    await controller.invoke(space, 'update_voting_delay', {
      new_delay: BigInt(1234),
    });
  }).timeout(600000);

  it('The controller can update the min voting duration', async () => {
    await controller.invoke(space, 'update_min_voting_duration', {
      new_min_duration: BigInt(1234),
    });
  }).timeout(600000);

  it('The controller can update the max voting duration', async () => {
    await controller.invoke(space, 'update_max_voting_duration', {
      new_max_duration: BigInt(1234),
    });
  }).timeout(600000);

  it('The controller can update the proposal threshold', async () => {
    await controller.invoke(space, 'update_proposal_threshold', {
      new_threshold: SplitUint256.fromUint(BigInt(1234)),
    });
  }).timeout(600000);
});
