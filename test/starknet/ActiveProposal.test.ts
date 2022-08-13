import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { vanillaSetup } from '../shared/setup';
import { StarknetContract, Account } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { getProposeCalldata } from '@snapshot-labs/sx/dist/utils/encoding';
import { PROPOSE_SELECTOR } from '../shared/constants';

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
    const proposalCallData = getProposeCalldata(
      user.address,
      utils.intsSequence.IntsSequence.LEFromString(''),
      vanillaExecutionStrategy.address,
      [vanillaVotingStrategy.address],
      [[]],
      []
    );

    // Create a proposal
    await user.invoke(vanillaAuthenticator, 'authenticate', {
      target: space.address,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposalCallData,
    });
  });

  it('Fails to add an executor if a proposal is active', async () => {
    try {
      await controller.invoke(space, 'add_executors', {
        to_add: [vanillaExecutionStrategy.address],
      });
      throw { message: 'should not add an executor' };
    } catch (error: any) {
      expect(error.message).to.contain('Some proposals are still active');
    }
  });

  it('Fails to remove an executor if a proposal is active', async () => {
    try {
      await controller.invoke(space, 'remove_executors', {
        to_remove: [vanillaExecutionStrategy.address],
      });
      throw { message: 'should not remove an executor' };
    } catch (error: any) {
      expect(error.message).to.contain('Some proposals are still active');
    }
  });

  it('Fails to add a voting strategy if a proposal is active', async () => {
    try {
      await controller.invoke(space, 'add_voting_strategies', {
        to_add: [vanillaVotingStrategy.address],
        params_flat: [],
      });
      throw { message: 'should not add a voting strategy' };
    } catch (error: any) {
      expect(error.message).to.contain('Some proposals are still active');
    }
  });

  it('Fails to remove a voting strategy if a proposal is active', async () => {
    try {
      await controller.invoke(space, 'remove_voting_strategies', {
        to_remove: [vanillaVotingStrategy.address],
      });
      throw { message: 'should not remove a voting strategy' };
    } catch (error: any) {
      expect(error.message).to.contain('Some proposals are still active');
    }
  });

  it('Fails to add an authenticator if a proposal is active', async () => {
    try {
      await controller.invoke(space, 'add_authenticators', {
        to_add: [vanillaAuthenticator.address],
      });
      throw { message: 'should not add an authenticator' };
    } catch (error: any) {
      expect(error.message).to.contain('Some proposals are still active');
    }
  });

  it('Fails to remove an authenticator if a proposal is active', async () => {
    try {
      await controller.invoke(space, 'remove_authenticators', {
        to_remove: [vanillaAuthenticator.address],
      });
      throw { message: 'should not remove an authenticator' };
    } catch (error: any) {
      expect(error.message).to.contain('Some proposals are still active');
    }
  });
});
