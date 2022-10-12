import { StarknetContract } from 'hardhat/types/runtime';
import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { utils } from '@snapshot-labs/sx';

async function setup() {
  const testWordsFactory = await starknet.getContractFactory(
    './contracts/starknet/TestContracts/Test_FeltUtils.cairo'
  );
  const testWords = await testWordsFactory.deploy();
  return {
    testWords: testWords as StarknetContract,
  };
}

describe('Felt Utils:', () => {
  it('The library should covert 4 64 bit words to a Uint256', async () => {
    const { testWords } = await setup();
    const word1 = BigInt(utils.bytes.bytesToHex(ethers.utils.randomBytes(2)));
    const word2 = BigInt(utils.bytes.bytesToHex(ethers.utils.randomBytes(2)));
    const word3 = BigInt(utils.bytes.bytesToHex(ethers.utils.randomBytes(2)));
    const word4 = BigInt(utils.bytes.bytesToHex(ethers.utils.randomBytes(2)));
    const { uint256: uint256 } = await testWords.call('testWordsToUint256', {
      word1: word1,
      word2: word2,
      word3: word3,
      word4: word4,
    });
    const uint = utils.words64.wordsToUint(word1, word2, word3, word4);

    expect(
      new utils.splitUint256.SplitUint256(
        `0x${uint256.low.toString(16)}`,
        `0x${uint256.high.toString(16)}`
      )
    ).to.deep.equal(utils.splitUint256.SplitUint256.fromUint(uint));
  }).timeout(600000);

  it('The library should covert a felt into 4 words', async () => {
    const { testWords } = await setup();
    const input = BigInt(utils.bytes.bytesToHex(ethers.utils.randomBytes(31)));
    const { words: words } = await testWords.call('testFeltToWords', {
      input: input,
    });
    const uint = utils.words64.wordsToUint(words.word_1, words.word_2, words.word_3, words.word_4);
    expect(uint).to.deep.equal(input);
  }).timeout(600000);
});
