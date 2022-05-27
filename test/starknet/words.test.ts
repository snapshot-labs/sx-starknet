import { StarknetContract } from 'hardhat/types/runtime';
import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { wordsToUint, bytesToHex } from '../shared/helpers';

async function setup() {
  const testWordsFactory = await starknet.getContractFactory(
    './contracts/starknet/TestContracts/Test_words.cairo'
  );
  const testWords = await testWordsFactory.deploy();
  return {
    testWords: testWords as StarknetContract,
  };
}

describe('Words:', () => {
  it('The contract should covert a felt into 4 words', async () => {
    const { testWords } = await setup();
    const input = BigInt(bytesToHex(ethers.utils.randomBytes(31)));
    const { words: words } = await testWords.call('test_felt_to_words', {
      input: input,
    });
    const uint = wordsToUint(words.word_1, words.word_2, words.word_3, words.word_4);
    expect(uint).to.deep.equal(input);
  }).timeout(600000);
});
