import { StarknetContract } from 'hardhat/types/runtime';
import { expect } from 'chai';
import { starknet } from 'hardhat';
import { vanillaSetup } from './shared/setup';
import { Account } from '@shardlabs/starknet-hardhat-plugin/dist/account';

describe('Controller', () => {
  let vanillaSpace: StarknetContract;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let zodiacRelayer: StarknetContract;
  let account: Account;

  before(async function () {
    this.timeout(800000);

    ({ vanillaSpace, vanillaAuthenticator, vanillaVotingStrategy, zodiacRelayer, account } =
      await vanillaSetup());
  });

  it('Should be able to update controller if properly called', async () => {
    const new_controller = await starknet.deployAccount('OpenZeppelin');

    console.log(account.publicKey);
    await account.invoke(vanillaSpace, 'update_controller', {
      new_controller: new_controller.starknetContract.address,
    });

    // Now updating again with the new controller
    await new_controller.invoke(vanillaSpace, 'update_controller', {
      new_controller: account.starknetContract.address,
    });
  }).timeout(600000);

  it('Should not be able to update controller if not properly called', async () => {
    const fake_controller = await starknet.deployAccount('OpenZeppelin');

    try {
      await fake_controller.invoke(vanillaSpace, 'update_controller', {
        new_controller: fake_controller.publicKey,
      });
    } catch (error: any) {
      expect(error.message).to.contain('Ownable: caller is not the owner');
    }
  }).timeout(600000);
});
