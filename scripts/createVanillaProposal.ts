import fetch from 'cross-fetch';
import fs from 'fs';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { ethers } from 'ethers';
import { utils } from '@snapshot-labs/sx';
import { defaultProvider, Account, ec, hash } from 'starknet';
import { domain, Propose, proposeTypes } from '../test/shared/types';
import { PROPOSE_SELECTOR } from '../test/shared/constants';

async function main() {
  global.fetch = fetch;

  const starkAccount = new Account(
    defaultProvider,
    process.env.ARGENT_X_ADDRESS!,
    ec.getKeyPair(process.env.ARGENT_X_PK!)
  );
  const ethAccount = new ethers.Wallet(process.env.ETH_PK_1!);

  const deployment = JSON.parse(fs.readFileSync('./deployments/goerli2.json').toString());
  const vanillaAuthenticatorAddress = deployment.space.authenticators.vanilla;
  const zodiacExecutionStrategyAddress = deployment.space.executionStrategies.zodiac;
  const spaceAddress = deployment.space.address;

  const goerliChainId = 5;
  const zodiacModuleAddress = '0x66072142ed77472728a146F00f137982e72F42Dc';
  const tx1: utils.encoding.MetaTransaction = {
    to: '0x2842c82E20ab600F443646e1BC8550B44a513D82',
    value: ethers.utils.parseEther('0.01').toHexString(),
    data: '0x',
    operation: 0,
    nonce: 0,
  };
  const executionHash = utils.splitUint256.SplitUint256.fromHex(
    utils.encoding.createExecutionHash([tx1], zodiacModuleAddress, goerliChainId).executionHash
  );

  const usedVotingStrategies = ['0x0']; // Vanilla voting strategy is index 0
  const metadataUri = 'Hello and welcome to Snapshot X. This is the future of governance.';
  const metadataUriInts = utils.intsSequence.IntsSequence.LEFromString(metadataUri);
  const userVotingStrategyParams = [[]];
  const executionStrategy = zodiacExecutionStrategyAddress;
  const executionParams = [zodiacModuleAddress, executionHash.low, executionHash.high];
  const proposerEthAddress = ethAccount.address;
  const proposeCalldata = utils.encoding.getProposeCalldata(
    proposerEthAddress,
    metadataUriInts,
    executionStrategy,
    usedVotingStrategies,
    userVotingStrategyParams,
    executionParams
  );

  const { transaction_hash: txHash } = await starkAccount.execute(
    {
      contractAddress: vanillaAuthenticatorAddress,
      entrypoint: 'authenticate',
      calldata: [spaceAddress, PROPOSE_SELECTOR, proposeCalldata.length, ...proposeCalldata],
    },
    undefined,
    { maxFee: '857400005301800' }
  );
  console.log('Waiting for confirmation, transaction hash: ', txHash);
  await defaultProvider.waitForTransaction(txHash);
  console.log('---- PROPOSAL CREATED ----');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
