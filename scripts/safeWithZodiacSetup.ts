import dotenv from 'dotenv';
import fs from 'fs';
import fetch from 'cross-fetch';
import { ethers } from 'ethers';
import { Contract } from 'starknet';
import { executeContractCallWithSigners } from '../test/shared/safeUtils';

// import {Safe} from '@gnosis.pm/safe-contracts';

dotenv.config();

async function main() {
  global.fetch = fetch;
  console.log(1);
  const provider = new ethers.providers.JsonRpcProvider(process.env.GOERLI_NODE_URL!);

  const ethAccount = new ethers.Wallet(process.env.ETH_PK_1!, provider);

  const safeAddress = '0x11455A53117B5142A8Bf5E6DcaFcD504eb633Ae1';
  //   const starknetCoreAddress = '0xde29d060D45901Fb19ED6C6e959EB22d8626708e'; // Goerli1
  const starknetCoreAddress = '0xa4eD3aD27c294565cB0DCc993BDdCC75432D498c'; // Goerli2

  const spaceAddress = '0x7e6e9047eb910f84f7e3b86cea7b1d7779c109c970a39b54379c1f4fa395b28';
  const zodiacRelayerAddress = '0x21dda40770f4317582251cffd5a0202d6b223dc167e5c8db25dc887d11eba81';
  const moduleProxyFactoryAddress = '0x00000000000DC7F163742Eb4aBEf650037b1f588';
  const zodiacModuleMasterAddress = '0xC61BF210c37150B39FB97ae1C9f74e9B00E64620';

  const safeInterface = new ethers.utils.Interface(
    JSON.parse(
      fs.readFileSync(
        'node_modules/@gnosis.pm/safe-contracts/build/artifacts/contracts/GnosisSafeL2.sol/GnosisSafeL2.json',
        'utf8'
      )
    ).abi
  );
  const safe = new ethers.Contract(safeAddress, safeInterface, ethAccount);

  const moduleProxyFactoryInterface = new ethers.utils.Interface(
    JSON.parse(
      fs.readFileSync(
        'artifacts/@gnosis.pm/zodiac/contracts/factory/ModuleProxyFactory.sol/ModuleProxyFactory.json',
        'utf8'
      )
    ).abi
  );
  const moduleProxyFactory = new ethers.Contract(
    moduleProxyFactoryAddress,
    moduleProxyFactoryInterface,
    ethAccount
  );

  const zodiacModuleMasterInterface = new ethers.utils.Interface(
    JSON.parse(
      fs.readFileSync(
        './artifacts/contracts/ethereum/ZodiacModule/SnapshotXL1Executor.sol/SnapshotXL1Executor.json',
        'utf8'
      )
    ).abi
  );
  const zodiacModuleMaster = new ethers.Contract(
    zodiacModuleMasterAddress,
    zodiacModuleMasterInterface,
    ethAccount
  );

  const encodedInitParams = ethers.utils.defaultAbiCoder.encode(
    ['address', 'address', 'address', 'address', 'uint256', 'uint256[]'],
    [
      safeAddress,
      safeAddress,
      safeAddress,
      starknetCoreAddress,
      zodiacRelayerAddress,
      [spaceAddress],
    ]
  );
  const initData = zodiacModuleMaster.interface.encodeFunctionData('setUp', [encodedInitParams]);
  const masterCopyAddress = zodiacModuleMaster.address.toLowerCase().replace(/^0x/, '');
  //This is the bytecode of the module proxy contract
  const byteCode =
    '0x602d8060093d393df3363d3d373d3d3d363d73' +
    masterCopyAddress +
    '5af43d82803e903d91602b57fd5bf3';
  const salt = ethers.utils.solidityKeccak256(
    ['bytes32', 'uint256'],
    [ethers.utils.solidityKeccak256(['bytes'], [initData]), '0x01']
  );
  const expectedAddress = ethers.utils.getCreate2Address(
    moduleProxyFactory.address,
    salt,
    ethers.utils.keccak256(byteCode)
  );
  await moduleProxyFactory
    .connect(ethAccount)
    .deployModule(zodiacModuleMaster.address, initData, '0x01');

  const zodiacModule = zodiacModuleMaster.attach(expectedAddress);

  // Activating the zodiac module in the gnosis safe
  await executeContractCallWithSigners(
    safe,
    safe,
    'enableModule',
    [zodiacModule.address],
    [ethAccount]
  );
  console.log('Zodiac Module deployed at: ', expectedAddress);
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
