import { expect } from 'chai';
import axios from 'axios';
import { ethers } from 'hardhat';
import { uint256 } from 'starknet';
import { executeContractCallWithSigners } from './external/safeUtils';
import path from 'path';
import fs from 'fs/promises';

export async function getCompiledCode(filename: string) {
  const sierraFilePath = path.join(
    __dirname,
    `../starknet/target/dev/${filename}.contract_class.json`,
  );
  const casmFilePath = path.join(
    __dirname,
    `../starknet/target/dev/${filename}.compiled_contract_class.json`,
  );

  const code = [sierraFilePath, casmFilePath].map(async (filePath) => {
    const file = await fs.readFile(filePath);
    return JSON.parse(file.toString("ascii"));
  });

  const [sierraCode, casmCode] = await Promise.all(code);

  return {
    sierraCode,
    casmCode,
  };
}

export async function safeWithL1AvatarExecutionStrategySetup(
  safeSigner: ethers.SignerWithAddress,
  starknetCoreAddress: string,
  spaceAddress: string,
  ethRelayerAddress: string,
  quorum: number,
) {
  const GnosisSafeL2 = await ethers.getContractFactory(
    '@safe-global/safe-contracts/contracts/SafeL2.sol:SafeL2',
  );
  const FactoryContract = await ethers.getContractFactory(
    '@safe-global/safe-contracts/contracts/proxies/SafeProxyFactory.sol:SafeProxyFactory',
  );
  const singleton = await GnosisSafeL2.deploy();
  const factory = await FactoryContract.deploy();

  const template = await factory.callStatic.createProxyWithNonce(singleton.address, '0x', 0);
  await factory.createProxyWithNonce(singleton.address, '0x', 0);

  const safe = GnosisSafeL2.attach(template);
  await safe.setup(
    [safeSigner.address],
    1,
    ethers.constants.AddressZero,
    '0x',
    ethers.constants.AddressZero,
    ethers.constants.AddressZero,
    0,
    ethers.constants.AddressZero,
  );

  const moduleFactoryContract = await ethers.getContractFactory('ModuleProxyFactory');
  const moduleFactory = await moduleFactoryContract.deploy();

  const L1AvatarExecutionStrategyFactory = await ethers.getContractFactory(
    'L1AvatarExecutionStrategyMockMessaging',
  );

  // Deploying the singleton master contract (not initialized)
  const masterL1AvatarExecutionStrategy = await L1AvatarExecutionStrategyFactory.deploy();

  const initData = masterL1AvatarExecutionStrategy.interface.encodeFunctionData('setUp', [
    safeSigner.address,
    safe.address,
    starknetCoreAddress,
    ethRelayerAddress,
    [spaceAddress],
    quorum,
  ]);

  const masterCopyAddress = masterL1AvatarExecutionStrategy.address
    .toLowerCase()
    .replace(/^0x/, '');

  //This is the bytecode of the module proxy contract
  const byteCode =
    '0x602d8060093d393df3363d3d373d3d3d363d73' +
    masterCopyAddress +
    '5af43d82803e903d91602b57fd5bf3';

  const salt = ethers.utils.solidityKeccak256(
    ['bytes32', 'uint256'],
    [ethers.utils.solidityKeccak256(['bytes'], [initData]), '0x01'],
  );

  const expectedAddress = ethers.utils.getCreate2Address(
    moduleFactory.address,
    salt,
    ethers.utils.keccak256(byteCode),
  );
  expect(
    await moduleFactory.deployModule(masterL1AvatarExecutionStrategy.address, initData, '0x01'),
  )
    .to.emit(moduleFactory, 'ModuleProxyCreation')
    .withArgs(expectedAddress, masterL1AvatarExecutionStrategy.address);
  const L1AvatarExecutionStrategy = L1AvatarExecutionStrategyFactory.attach(expectedAddress);

  await executeContractCallWithSigners(
    safe,
    safe,
    'enableModule',
    [L1AvatarExecutionStrategy.address],
    [safeSigner],
  );

  return {
    l1AvatarExecutionStrategy: L1AvatarExecutionStrategy as ethers.Contract,
    safe: safe as ethers.Contract,
  };
}

export async function increaseEthBlockchainTime(networkUrl: string, seconds: number) {
  await axios({
    method: 'post',
    url: networkUrl,
    data: { id: 1337, jsonrpc: '2.0', method: 'evm_increaseTime', params: [seconds] },
  });
}

export function extractMessagePayload(
  message_payload: any,
): [proposalId: any, proposal: any, votes: any] {
  const proposalId = uint256.uint256ToBN({
    low: message_payload[1],
    high: message_payload[2],
  });
  const proposal = {
    startTimestamp: message_payload[3],
    minEndTimestamp: message_payload[4],
    maxEndTimestamp: message_payload[5],
    finalizationStatus: message_payload[6],
    executionPayloadHash: message_payload[7],
    executionStrategy: message_payload[8],
    authorAddressType: message_payload[9],
    author: message_payload[10],
    activeVotingStrategies: uint256.uint256ToBN({
      low: message_payload[11],
      high: message_payload[12],
    }),
  };
  const forVotes = uint256.uint256ToBN({
    low: message_payload[13],
    high: message_payload[14],
  });
  const againstVotes = uint256.uint256ToBN({
    low: message_payload[15],
    high: message_payload[16],
  });
  const abstainVotes = uint256.uint256ToBN({
    low: message_payload[17],
    high: message_payload[18],
  });
  const votes = {
    votesFor: forVotes,
    votesAgainst: againstVotes,
    votesAbstain: abstainVotes,
  }
  return [proposalId, proposal, votes];
}

// From sx.js
export function getRSVFromSig(sig: string) {
  if (sig.startsWith('0x')) {
    sig = sig.substring(2);
  }
  const r = `0x${sig.substring(0, 64)}`;
  const s = `0x${sig.substring(64, 64 * 2)}`;
  const v = `0x${sig.substring(64 * 2)}`;
  return { r, s, v };
}
