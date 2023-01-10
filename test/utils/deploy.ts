import { starknet } from 'hardhat';
import { OpenZeppelinAccount } from '@shardlabs/starknet-hardhat-plugin/dist/src/account';
import { StarknetContract, StringMap } from 'hardhat/types';

export async function declareAndDeployContract(
  contractName: string,
  args?: StringMap,
  account?: OpenZeppelinAccount
): Promise<StarknetContract> {
  if (!account) {
    account = await getAccount(1);
  }

  const factory = await starknet.getContractFactory(contractName);
  await account.declare(factory);

  return account.deploy(factory, args);
}

export async function getAccount(index: number): Promise<OpenZeppelinAccount> {
  const pre_accs = (await starknet.devnet.getPredeployedAccounts())[index];
  return starknet.OpenZeppelinAccount.getAccountFromAddress(pre_accs.address, pre_accs.private_key);
}
