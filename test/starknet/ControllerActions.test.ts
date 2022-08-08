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
    const votingStrategies: string[] = ['0x1234', '0x4567'];
    const votingStrategyParams: string[][] = [['0x1', '0x2', '0x0'], []];
    const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);
    await controller.invoke(space, 'add_voting_strategies', {
      to_add: votingStrategies,
      params_flat: votingStrategyParamsFlat,
    });
    await controller.invoke(space, 'remove_voting_strategies', {
      to_remove: votingStrategies,
    });
  }).timeout(600000);
});
