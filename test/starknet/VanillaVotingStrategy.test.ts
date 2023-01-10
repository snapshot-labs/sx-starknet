import { StarknetContract } from 'hardhat/types/runtime';
import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { utils } from '@snapshot-labs/sx';
import { declareAndDeployContract } from '../utils/deploy';

async function setup() {
  const vanillaVotingStrategy = await declareAndDeployContract(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  return {
    vanillaVotingStrategy: vanillaVotingStrategy as StarknetContract,
  };
}

describe('Snapshot X Vanilla Voting Strategy:', () => {
  it('The voting strategy should return a voting power of 1', async () => {
    const { vanillaVotingStrategy } = await setup();
    const { voting_power: vp } = await vanillaVotingStrategy.call('getVotingPower', {
      timestamp: 1,
      voter_address: { value: BigInt(ethers.Wallet.createRandom().address) },
      params: [],
      user_params: [],
    });
    expect(
      new utils.splitUint256.SplitUint256(`0x${vp.low.toString(16)}`, `0x${vp.high.toString(16)}`)
    ).to.deep.equal(utils.splitUint256.SplitUint256.fromUint(BigInt(1)));
  }).timeout(600000);
});
