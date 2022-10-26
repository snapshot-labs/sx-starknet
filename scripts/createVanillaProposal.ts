import fetch from 'cross-fetch';
import fs from 'fs';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { ethers } from 'ethers';
import { utils } from '@snapshot-labs/sx';
import { Provider, defaultProvider, Account, ec, hash } from 'starknet';
import { domain, Propose, proposeTypes } from '../test/shared/types';
import { PROPOSE_SELECTOR } from '../test/shared/constants';

async function main() {
  global.fetch = fetch;

  const provider = process.env.STARKNET_PROVIDER_BASE_URL === undefined ?
  defaultProvider :
    new Provider({
      sequencer: {
        baseUrl: process.env.STARKNET_PROVIDER_BASE_URL!,
        feederGatewayUrl: 'feeder_gateway',
        gatewayUrl: 'gateway',
      }, 
  });

  const starkAccount = new Account(
    provider,
    process.env.ACCOUNT_ADDRESS!,
    ec.getKeyPair(process.env.ACCOUNT_PRIVATE_KEY!)
  );
  const ethAccount = new ethers.Wallet(process.env.ETH_PK_1!);

  const deployment = JSON.parse(fs.readFileSync('./deployments/goerli5.json').toString());
  const vanillaAuthenticatorAddress = deployment.spaces[0].authenticators.vanilla;
  const zodiacExecutionStrategyAddress = deployment.spaces[0].executionStrategies.zodiac;
  const spaceAddress = deployment.spaces[0].address;

  const goerliChainId = 5;
  const zodiacModuleAddress = '0xa88f72e92cc519d617b684F8A78d3532E7bb61ca';
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
    { maxFee: '89250000000000000' }
  );
  console.log('Waiting for confirmation, transaction hash: ', txHash);
  await provider.waitForTransaction(txHash);
  console.log('---- PROPOSAL CREATED ----');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
