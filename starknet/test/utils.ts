import { expect } from 'chai';
import { ethers } from 'hardhat';
import { executeContractCallWithSigners } from './safeUtils';

export async function safeWithL1AvatarExecutionStrategySetup(
  safeSigner: ethers.SignerWithAddress,
  starknetCoreAddress: string,
  spaceAddress: string,
  ethRelayerAddress: string,
  quorum: number,
) {
  const GnosisSafeL2 = await ethers.getContractFactory(
    '@gnosis.pm/safe-contracts/contracts/GnosisSafeL2.sol:GnosisSafeL2',
  );
  const FactoryContract = await ethers.getContractFactory(
    '@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol:GnosisSafeProxyFactory',
  );
  const singleton = await GnosisSafeL2.deploy();
  const factory = await FactoryContract.deploy();

  const template = await factory.callStatic.createProxy(singleton.address, '0x');
  await factory.createProxy(singleton.address, '0x');

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

  //deploying singleton master contract
  const masterL1AvatarExecutionStrategy = await L1AvatarExecutionStrategyFactory.deploy(
    '0x0000000000000000000000000000000000000001',
    '0x0000000000000000000000000000000000000001',
    '0x0000000000000000000000000000000000000001',
    1,
    [],
    0,
  );
  const encodedInitParams = ethers.utils.defaultAbiCoder.encode(
    ['address', 'address', 'address', 'uint256', 'uint256[]', 'uint256'],
    [safe.address, safe.address, starknetCoreAddress, ethRelayerAddress, [spaceAddress], quorum],
  );

  const initData = masterL1AvatarExecutionStrategy.interface.encodeFunctionData('setUp', [
    encodedInitParams,
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
