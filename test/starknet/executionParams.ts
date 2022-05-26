import { StarknetContract } from 'hardhat/types/runtime';
import { expect } from 'chai';
import { starknet } from 'hardhat';
import { createStarknetExecutionParams, Call } from './shared/executionParams';

describe('Execution Parameters:', () => {
  it('Creates a valid empty array', async () => {
    const calls: Call[] = [];
    const executionParams = createStarknetExecutionParams(calls);

    expect(executionParams).to.deep.equal([]);
  }).timeout(600000);

  it('Creates a valid array with a single call', async () => {
    const call = {
      to: BigInt('0x123'),
      functionSelector: BigInt('0x456'),
      calldata: [BigInt(1), BigInt(2)],
    };
    const calls: Call[] = [call];
    const executionParams = createStarknetExecutionParams(calls);
    const expected = [
      BigInt(5),
      call.to,
      call.functionSelector,
      BigInt(call.calldata.length),
      BigInt(0),
      ...call.calldata,
    ];

    expect(executionParams).to.deep.equal(expected);
  }).timeout(600000);

  it('Creates a valid array with two calls', async () => {
    const call1 = {
      to: BigInt('0x123'),
      functionSelector: BigInt('0x456'),
      calldata: [BigInt(1), BigInt(2)],
    };
    const call2 = { to: BigInt('0x789'), functionSelector: BigInt('0xabc'), calldata: [] };
    const calls: Call[] = [call1, call2];
    const executionParams = createStarknetExecutionParams(calls);
    const expected = [
      BigInt(9),
      call1.to,
      call1.functionSelector,
      BigInt(call1.calldata.length),
      BigInt(0),
      call2.to,
      call2.functionSelector,
      BigInt(call2.calldata.length),
      BigInt(call1.calldata.length),
      ...call1.calldata,
      ...call2.calldata,
    ];

    expect(executionParams).to.deep.equal(expected);
  }).timeout(600000);

  it('Creates a valid array with three calls', async () => {
    const call1 = {
      to: BigInt('0x123'),
      functionSelector: BigInt('0x456'),
      calldata: [BigInt(1), BigInt(2)],
    };
    const call2 = { to: BigInt('0x789'), functionSelector: BigInt('0xabc'), calldata: [] };
    const call3 = {
      to: BigInt('0xaaa'),
      functionSelector: BigInt('0xbbb'),
      calldata: [BigInt(3), BigInt(4)],
    };
    const calls: Call[] = [call1, call2, call3];
    const executionParams = createStarknetExecutionParams(calls);
    const expected = [
      BigInt(13),
      call1.to,
      call1.functionSelector,
      BigInt(call1.calldata.length),
      BigInt(0),
      call2.to,
      call2.functionSelector,
      BigInt(call2.calldata.length),
      BigInt(call1.calldata.length),
      call3.to,
      call3.functionSelector,
      BigInt(call3.calldata.length),
      BigInt(call1.calldata.length + call2.calldata.length),
      ...call1.calldata,
      ...call2.calldata,
      ...call3.calldata,
    ];

    expect(executionParams).to.deep.equal(expected);
  }).timeout(600000);
});
