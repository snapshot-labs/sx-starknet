import { expect } from 'chai';
import { starknet } from 'hardhat';
import { vanillaSetup } from '../shared/setup';
import { StarknetContract, Account } from 'hardhat/types';
import { flatten2DArray } from '../shared/helpers';
import { SplitUint256 } from '../shared/types';

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
    const votingStrategies: bigint[] = [BigInt(1234), BigInt(4567)];
    const votingStrategyParams: bigint[][] = [[BigInt(1), BigInt(2), BigInt(0)], []];
    const votingStrategyParamsFlat: bigint[] = flatten2DArray(votingStrategyParams);
    await controller.invoke(space, 'add_voting_strategies', {
      to_add: votingStrategies,
      params_flat: votingStrategyParamsFlat,
    });
    await controller.invoke(space, 'remove_voting_strategies', {
      to_remove: votingStrategies,
    });
  }).timeout(600000);

  it('The controller can add and remove authenticators', async () => {
    const authenticators: bigint[] = [BigInt(1234), BigInt(4567)];
    await controller.invoke(space, 'add_authenticators', {
      to_add: authenticators,
    });
    await controller.invoke(space, 'remove_authenticators', {
      to_remove: authenticators,
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
