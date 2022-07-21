import fs, { access } from 'fs';
import fetch from 'cross-fetch';
import { Provider, defaultProvider, json, Contract, Account, ec, hash } from 'starknet';
import { utils } from '@snapshot-labs/sx';
import { ethers } from 'ethers';
import { toBN } from 'starknet/dist/utils/number';

async function main() {
  global.fetch = fetch;

  const starkKeyPair = ec.getKeyPair(
    process.env.ARGENT_PRIVATE_KEY!
  );

  const account = new Account(
    defaultProvider,
    process.env.ARGENT_ACCOUNT_ADDRESS!,
    starkKeyPair
  );
  const metadataUri = utils.strings.strToShortStringArr(
    'Hello and welcome to Snapshot X. This is the future of governance.'
  );
  const proposerEthAddress = ethers.Wallet.createRandom().address;
  const spaceAddress = '0x4188ccd03d5366349ed9c4a22a435f621120529ddf5db4fcfc11f5fdda92f2';
  const usedVotingStrategies = [
    BigInt('0x11621cda94a730cbf7cf9a6a99f3f27f7e4451cc843a47bbed4e7012596f105'),
  ];
  const userVotingParamsAll = [[]];
  const executionStrategy = BigInt(
    '0x22c0bafb1f1ee8ecb085905456be94cf524adb6eb5f49f8c215727036966c68'
  );
  const executionParams: bigint[] = [];
  const proposeCalldata = utils.encoding.getProposeCalldata(
    proposerEthAddress,
    metadataUri,
    executionStrategy,
    usedVotingStrategies,
    userVotingParamsAll,
    executionParams
  );
  const proposeCalldataHex = proposeCalldata.map((x) => '0x' + x.toString(16));
  const calldata = [
    spaceAddress,
    hash.getSelectorFromName('propose'),
    proposeCalldataHex.length,
    ...proposeCalldataHex,
  ];

  const { transaction_hash: txHash } = await account.execute(
    {
      contractAddress: '0x2713acc3a940dcfa33a9675ad9ba67b4cdf09cb33d788a0a366e13ffd3ab0eb',
      entrypoint: 'authenticate',
      calldata: calldata,
    },
    undefined,
    { maxFee: '857400005301800' }
  );
  console.log(txHash);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
