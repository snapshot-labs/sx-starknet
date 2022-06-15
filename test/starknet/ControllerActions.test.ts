import { expect } from 'chai';
import { starknet } from 'hardhat';
import { vanillaSetup } from '../shared/setup';
import { StarknetContract, Account } from 'hardhat/types';

describe('Controller', () => {
  let space: StarknetContract;
  let controller: Account;

  before(async function () {
    this.timeout(800000);

    ({ space, controller } = await vanillaSetup());
  });

  it('Should be able to update controller if properly called', async () => {
    const newController = await starknet.deployAccount('OpenZeppelin');

    await controller.invoke(space, 'update_controller', {
      new_controller: newController.starknetContract.address,
    });

    // Now updating again with the new controller
    await newController.invoke(space, 'update_controller', {
      new_controller: controller.starknetContract.address,
    });
  }).timeout(600000);

  it('Should not be able to update controller if not properly called', async () => {
    const fakeController = await starknet.deployAccount('OpenZeppelin');

    try {
      await fakeController.invoke(space, 'update_controller', {
        new_controller: fakeController.starknetContract.address,
      });
    } catch (error: any) {
      expect(error.message).to.contain('Ownable: caller is not the owner');
    }
  }).timeout(600000);
});
