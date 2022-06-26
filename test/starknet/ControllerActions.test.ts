import { expect } from 'chai';
import { starknet } from 'hardhat';
import { vanillaSetup } from '../shared/setup';
import { StarknetContract, Account } from 'hardhat/types';
import { flatten2DArray } from '../shared/helpers';

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
});
