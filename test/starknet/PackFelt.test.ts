import { StarknetContract } from 'hardhat/types/runtime';
import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { utils } from '@snapshot-labs/sx';

async function setup() {
  const testPackFeltFactory = await starknet.getContractFactory(
    './contracts/starknet/TestContracts/Test_PackFelt.cairo'
  );
  const testPackFelt = await testPackFeltFactory.deploy();
  return {
    testPackFelt: testPackFelt as StarknetContract,
  };
}

describe('Felt Packings:', () => {
  it('The library should pack a felt', async () => {
    const { testPackFelt } = await setup();
    const num1 = 1234234;
    const num2 = 3453532;
    const num3 = 56534453;
    const num4 = 23;
    const { packed: packed } = await testPackFelt.call('test_pack_felt', {
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
    } = await testPackFelt.call('test_unpack_felt', { packed: packed });
    expect(BigInt(num1)).to.deep.equal(_num1);
    expect(BigInt(num2)).to.deep.equal(_num2);
    expect(BigInt(num3)).to.deep.equal(_num3);
    expect(BigInt(num4)).to.deep.equal(_num4);
  }).timeout(600000);
});
