import { StarknetContract } from 'hardhat/types/runtime';
import { expect } from 'chai';
import { starknet } from 'hardhat';
import { wordsToUint } from './shared/helpers';
import { SplitUint256 } from './shared/types';

async function setup() {
  const testWordsFactory = await starknet.getContractFactory(
    './contracts/starknet/test_contracts/test_words64_to_uint256.cairo'
  );
  const testWords = await testWordsFactory.deploy();
  return {
    testWords: testWords as StarknetContract,
  };
}

describe('Words 64 to Uint256:', () => {
  it('The contract should covert 4 64 bit words to a Uint256', async () => {
    const { testWords } = await setup();
    const word1 = BigInt(2342342);
    const word2 = BigInt(3423412);
    const word3 = BigInt(65746574);
    const word4 = BigInt(987653452);
    const { uint256: uint256 } = await testWords.call('test_words64_to_uint256', {
      word1: word1,
      word2: word2,
      word3: word3,
      word4: word4,
    });
    const uint = wordsToUint(word1, word2, word3, word4);

    expect(new SplitUint256(uint256.low, uint256.high)).to.deep.equal(SplitUint256.fromUint(uint));
  }).timeout(60000);
});
