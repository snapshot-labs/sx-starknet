import { StarknetContract } from 'hardhat/types/runtime';
import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { utils } from '@snapshot-labs/sx';

async function setup() {
  const testFeltUtilsFactory = await starknet.getContractFactory(
    './contracts/starknet/TestContracts/Test_FeltUtils.cairo'
  );
  const testFeltUtils = await testFeltUtilsFactory.deploy();
  return {
    testFeltUtils: testFeltUtils as StarknetContract,
  };
}

describe('Felt Utils:', () => {
  it('The library should covert 4 64 bit words to a Uint256', async () => {
    const { testFeltUtils } = await setup();
    const word1 = BigInt(utils.bytes.bytesToHex(ethers.utils.randomBytes(2)));
    const word2 = BigInt(utils.bytes.bytesToHex(ethers.utils.randomBytes(2)));
    const word3 = BigInt(utils.bytes.bytesToHex(ethers.utils.randomBytes(2)));
    const word4 = BigInt(utils.bytes.bytesToHex(ethers.utils.randomBytes(2)));
    const { uint256: uint256 } = await testFeltUtils.call('test_words_to_uint256', {
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

  it('The library should pack 4 32 bit numbers into a felt', async () => {
    const { testFeltUtils } = await setup();
    const num1 = utils.bytes.bytesToHex(ethers.utils.randomBytes(4));
    const num2 = utils.bytes.bytesToHex(ethers.utils.randomBytes(4));
    const num3 = utils.bytes.bytesToHex(ethers.utils.randomBytes(4));
    const num4 = utils.bytes.bytesToHex(ethers.utils.randomBytes(4));
    const { packed: packed } = await testFeltUtils.call('test_pack_felt', {
      num1: num1,
      num2: num2,
      num3: num3,
      num4: num4,
    });
    const {
      num1: _num1,
      num2: _num2,
      num3: _num3,
      num4: _num4,
    } = await testFeltUtils.call('test_unpack_felt', { packed: packed });
    expect(BigInt(num1)).to.deep.equal(_num1);
    expect(BigInt(num2)).to.deep.equal(_num2);
    expect(BigInt(num3)).to.deep.equal(_num3);
    expect(BigInt(num4)).to.deep.equal(_num4);
  }).timeout(600000);

  it('Packing should fail if a number greater than 32 bits is used', async () => {
    const { testFeltUtils } = await setup();
    const num1 = utils.bytes.bytesToHex(ethers.utils.randomBytes(4));
    const num2 = '0xfffff'; // 36 bits
    const num3 = utils.bytes.bytesToHex(ethers.utils.randomBytes(4));
    const num4 = utils.bytes.bytesToHex(ethers.utils.randomBytes(4));
    try {
      const { packed: packed } = await testFeltUtils.call('test_pack_felt', {
        num1: num1,
        num2: num2,
        num3: num3,
        num4: num4,
      });
    } catch (error: any) {
      expect(error.message).to.contain('FeltUtils: felt too big to be packed');
    }
  }).timeout(600000);
});
