import fs, { access } from 'fs';
import fetch from 'cross-fetch';
import { Provider, defaultProvider, json, Contract, Account, ec, hash } from 'starknet';
import { utils } from '@snapshot-labs/sx';
import { ethers } from 'ethers';
import { toBN } from 'starknet/dist/utils/number';

// Using deployment at: deployments/goerli2.json

async function main() {
  global.fetch = fetch;

  const account = new Account(
    defaultProvider,
    process.env.ARGENT_ACCOUNT_ADDRESS!,
    ec.getKeyPair(process.env.ARGENT_PRIVATE_KEY!)
  );

  // Generating propose calldata:
  const metadataUri = utils.strings.strToShortStringArr(
    'Hello and welcome to Snapshot X. This is the future of governance.'
  );
  const proposerEthAddress = ethers.Wallet.createRandom().address;
  const spaceAddress = '0x2e5804152c5cfb8f2c5de9109001fea295aee6e4c2ab18d16c3da808a39e29c';
  const usedVotingStrategies = [
    BigInt('0x434ae7044947e43c198352ef092a2b2318b8841282dbdd59d4ca978f90335a3'),
  ];
  const userVotingParamsAll = [[]];
  const executionStrategy = BigInt(
    '0x66240df298b5f2c53e2555e5299b4a78c762a78563d9feca778fd79bcbe288c'
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

  // Executing propose tx via the vanilla authenticator
  // const { transaction_hash: txHash } = await account.execute(
  //   {
  //     contractAddress: '0x5a57beb8cc06d4182b9764723aa572ec9fe6b3d03ec15fc368a0119c0e5266a',
  //     entrypoint: 'authenticate',
  //     calldata: calldata,
  //   },
  //   undefined,
  //   { maxFee: '857400005301800' }
  // );
  // console.log(txHash);

  const { transaction_hash: txHash } = await account.execute(
    {
      contractAddress: '0x26ff4b2c18c627853e942bc99ad9d03c4872ddf3908dbafce22a3153976b81b',
      entrypoint: 'update_quorum',
      calldata: ['0x2'],
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
