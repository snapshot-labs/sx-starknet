import { StarknetContract } from 'hardhat/types/runtime';
import { expect } from 'chai';
import { starknet } from 'hardhat';
import { utils } from '@snapshot-labs/sx';

async function setup() {
  const testArray2dFactory = await starknet.getContractFactory(
    './contracts/starknet/TestContracts/Test_array2d.cairo'
  );
  const testArray2d = await testArray2dFactory.deploy();
  return {
    testArray2d: testArray2d as StarknetContract,
  };
}

describe('2D Arrays:', () => {
  it('The library should be able to construct the 2D array type from a flat array and then retrieve the sub arrays individually.', async () => {
    const { testArray2d } = await setup();

    // Sub Arrays: [[5],[],[1,2,3],[7,9]]
    // Offsets: [0,1,1,4]
    const arr1: string[] = ['0x5'];
    const arr2: string[] = [];
    const arr3: string[] = ['0x1', '0x2', '0x3'];
    const arr4: string[] = ['0x7', '0x9'];
    const arr2d: string[][] = [arr1, arr2, arr3, arr4];
    const flatArray: string[] = utils.encoding.flatten2DArray(arr2d);

    const { array: array1 } = await testArray2d.call('test_array2d', {
      flat_array: flatArray,
      index: 0,
    });
    expect(array1.map((x: any) => '0x' + x.toString(16))).to.deep.equal(arr1);

    const { array: array2 } = await testArray2d.call('test_array2d', {
      flat_array: flatArray,
      index: 1,
    });
    expect(array2.map((x: any) => '0x' + x.toString(16))).to.deep.equal(arr2);

    const { array: array3 } = await testArray2d.call('test_array2d', {
      flat_array: flatArray,
      index: 2,
    });
    expect(array3.map((x: any) => '0x' + x.toString(16))).to.deep.equal(arr3);

    const { array: array4 } = await testArray2d.call('test_array2d', {
      flat_array: flatArray,
      index: 3,
    });
    expect(array4.map((x: any) => '0x' + x.toString(16))).to.deep.equal(arr4);

    // Sub Arrays: [[]]
    // Offsets: [0]
    const arr2d2 = [arr2];
    const flatArray2 = utils.encoding.flatten2DArray(arr2d2);
    const { array: array5 } = await testArray2d.call('test_array2d', {
      flat_array: flatArray2,
      index: 0,
    });
    expect(array5.map((x: any) => '0x' + x.toString(16))).to.deep.equal(arr2);
  }).timeout(600000);
});
