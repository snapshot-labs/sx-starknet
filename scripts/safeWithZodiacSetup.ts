import { expect } from 'chai';
import fs from 'fs';
import fetch from 'cross-fetch';
import { ethers } from 'ethers';
import { Contract } from 'starknet';
import { executeContractCallWithSigners } from '../test/shared/safeUtils';

async function main() {
  global.fetch = fetch;
  const provider = new ethers.providers.JsonRpcProvider(process.env.GOERLI_NODE_URL);
  const ethAccount = new ethers.Wallet(process.env.ETH_PK_1!, provider);

  const safeAddress = '0x11455A53117B5142A8Bf5E6DcaFcD504eb633Ae1';
  const starknetCoreAddress = '0xde29d060D45901Fb19ED6C6e959EB22d8626708e';
  const spaceAddress = '0x324fb879af5b650e31f7513bd19cf093f826ae3211022919cafcd08fca17700';
  const zodiacRelayerAddress = '0x7a0c890e6dc4dc445fb42c70579813ea33e7d3c37c2cfdbcb47cc059503747d';
  const moduleProxyFactoryAddress = '0x00000000000DC7F163742Eb4aBEf650037b1f588';
  const zodiacModuleMasterAddress = '0xC61BF210c37150B39FB97ae1C9f74e9B00E64620';

  const safeInterface = new ethers.utils.Interface(
    fs
      .readFileSync('./abi/@gnosis.pm/safe-contracts/contracts/GnosisSafeL2.sol/GnosisSafeL2.json')
      .toString()
  );
  const safe = new ethers.Contract(safeAddress, safeInterface, ethAccount);

  const moduleProxyFactoryInterface = new ethers.utils.Interface(
    fs
      .readFileSync(
        './abi/@gnosis.pm/zodiac/contracts/factory/ModuleProxyFactory.sol/ModuleProxyFactory.json'
      )
      .toString()
  );
  const moduleProxyFactory = new ethers.Contract(
    moduleProxyFactoryAddress,
    moduleProxyFactoryInterface,
    ethAccount
  );

  const zodiacModuleMasterInterface = new ethers.utils.Interface(
    fs
      .readFileSync(
        './abi/contracts/ethereum/ZodiacModule/SnapshotXL1Executor.sol/SnapshotXL1Executor.json'
      )
      .toString()
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
