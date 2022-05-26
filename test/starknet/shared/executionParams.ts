export interface Call {
  to: bigint;
  functionSelector: bigint;
  calldata: bigint[];
}

/**
 * For more info about the starknetExecutionParams layout, please see `contracts/starknet/execution_strategies/starknet.cairo`.
 */
export function createStarknetExecutionParams(callArray: Call[]): bigint[] {
  if (!callArray || callArray.length == 0) {
    return [];
  }

  // 1 because we need to count data_offset
  // 4 because there are four elements: `to`, `function_selector`, `calldata_len` and `calldata_offset`
  const dataOffset = BigInt(1 + callArray.length * 4);

  const executionParams = [dataOffset];
  let calldataIndex = 0;

  // First, layout the calls
  callArray.forEach((call) => {
    const subArr: bigint[] = [
      call.to,
      call.functionSelector,
      BigInt(call.calldata.length),
      BigInt(calldataIndex),
    ];
    calldataIndex += call.calldata.length;
    executionParams.push(...subArr);
  });

  // Then layout the calldata
  callArray.forEach((call) => {
    executionParams.push(...call.calldata);
  });
  return executionParams;
}
