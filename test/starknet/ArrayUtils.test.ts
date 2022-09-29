import { StarknetContract } from 'hardhat/types/runtime';
import { expect } from 'chai';
import { starknet } from 'hardhat';
import { hash } from 'starknet';
import { utils } from '@snapshot-labs/sx';
import { computeHashOnElements } from 'starknet/dist/utils/hash';

async function setup() {
  const testArrayUtilsFactory = await starknet.getContractFactory(
    './contracts/starknet/TestContracts/Test_ArrayUtils.cairo'
  );
  const testArrayUtils = await testArrayUtilsFactory.deploy();
  return {
    testArrayUtils: testArrayUtils as StarknetContract,
  };
}

describe('Array Utilities', () => {
  let testArrayUtils: StarknetContract;

  before(async function () {
    this.timeout(800000);
    const testArrayUtilsFactory = await starknet.getContractFactory(
      './contracts/starknet/TestContracts/Test_ArrayUtils.cairo'
    );
    testArrayUtils = await testArrayUtilsFactory.deploy();
  });
  it('The library should be able to construct the 2D array type from a flat array and then retrieve the sub arrays individually.', async () => {
    // Sub Arrays: [[5],[],[1,2,3],[7,9]]
    // Offsets: [0,1,1,4]
    const arr1: string[] = ['0x5'];
    const arr2: string[] = [];
    const arr3: string[] = ['0x1', '0x2', '0x3'];
    const arr4: string[] = ['0x7', '0x9'];
    const arr2d: string[][] = [arr1, arr2, arr3, arr4];
    const flatArray: string[] = utils.encoding.flatten2DArray(arr2d);

    const { array: array1 } = await testArrayUtils.call('test_array2d', {
      flat_array: flatArray,
      index: 0,
    });
    expect(array1.map((x: any) => '0x' + x.toString(16))).to.deep.equal(arr1);

    const { array: array2 } = await testArrayUtils.call('test_array2d', {
      flat_array: flatArray,
      index: 1,
    });
    expect(array2.map((x: any) => '0x' + x.toString(16))).to.deep.equal(arr2);

    const { array: array3 } = await testArrayUtils.call('test_array2d', {
      flat_array: flatArray,
      index: 2,
    });
    expect(array3.map((x: any) => '0x' + x.toString(16))).to.deep.equal(arr3);

    const { array: array4 } = await testArrayUtils.call('test_array2d', {
      flat_array: flatArray,
      index: 3,
    });
    expect(array4.map((x: any) => '0x' + x.toString(16))).to.deep.equal(arr4);

    // Sub Arrays: [[]]
    // Offsets: [0]
    const arr2d2 = [arr2];
    const flatArray2 = utils.encoding.flatten2DArray(arr2d2);
    const { array: array5 } = await testArrayUtils.call('test_array2d', {
      flat_array: flatArray2,
      index: 0,
    });
    expect(array5.map((x: any) => '0x' + x.toString(16))).to.deep.equal(arr2);
  }).timeout(600000);

  it('The library should be able to hash an array correctly', async () => {
    const { hash: hash } = await testArrayUtils.call('test_hash_array', {
      array: [1, 2, 3, 4],
    });
    expect('0x' + hash.toString(16)).to.deep.equal(computeHashOnElements([1, 2, 3, 4]));
    // empty array
    const { hash: hash2 } = await testArrayUtils.call('test_hash_array', {
      array: [],
    });
    expect('0x' + hash2.toString(16)).to.deep.equal(computeHashOnElements([]));
  }).timeout(600000);

  it('The library should be able to find a value in an array', async () => {
    const { found: found } = await testArrayUtils.call('test_find_in_array', {
      to_find: 1,
      array: [1, 2, 3, 4],
    });
    expect(found).to.deep.equal(BigInt(1));

    const { found: found2 } = await testArrayUtils.call('test_find_in_array', {
      to_find: 7,
      array: [1, 2, 3, 4],
    });
    expect(found2).to.deep.equal(BigInt(0));

    const { found: found3 } = await testArrayUtils.call('test_find_in_array', {
      to_find: 1,
      array: [],
    });
    expect(found3).to.deep.equal(BigInt(0));
  }).timeout(600000);

  it('The library should be able to assert whether duplicates exist in an array', async () => {
    await testArrayUtils.call('test_assert_no_duplicates', {
      array: [1, 2, 3, 4],
    });

    await testArrayUtils.call('test_assert_no_duplicates', {
      array: [],
    });

    try {
      await testArrayUtils.call('test_assert_no_duplicates', {
        array: [1, 0, 3, 4, 2, 0],
      });
    } catch (error: any) {
      expect(error.message).to.contain('Duplicate entry found');
    }
  }).timeout(600000);
});
