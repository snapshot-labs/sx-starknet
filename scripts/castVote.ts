import fs, { access } from 'fs';
import fetch from 'cross-fetch';
import { Provider, defaultProvider, json, Contract, Account, ec, hash } from 'starknet';
import { utils } from '@snapshot-labs/sx';
import { ethers } from 'ethers';
import { toBN } from 'starknet/dist/utils/number';

async function main() {
  global.fetch = fetch;

  const starkKeyPair = ec.getKeyPair(
    '637357425248906491734798339821267946913367255989714880095234737256366305691'
  );

  const account = new Account(
    defaultProvider,
    '0x0764c647e4c5f6e81c5baa1769b4554e44851a7b6319791fc6db9e25a32148bb',
    starkKeyPair
  );
  const spaceAddress = '0x4188ccd03d5366349ed9c4a22a435f621120529ddf5db4fcfc11f5fdda92f2';
  const voterEthAddress = ethers.Wallet.createRandom().address;
  const proposalId = BigInt(1);
  const choice = utils.choice.Choice.AGAINST;
  const usedVotingStrategies = [
    BigInt('0x11621cda94a730cbf7cf9a6a99f3f27f7e4451cc843a47bbed4e7012596f105'),
  ];
  const userVotingParamsAll = [[]];
  const voteCalldata = utils.encoding.getVoteCalldata(
    voterEthAddress,
    proposalId,
    choice,
    usedVotingStrategies,
    userVotingParamsAll
  );
  const voteCalldataHex = voteCalldata.map((x) => '0x' + x.toString(16));
  const calldata = [
    spaceAddress,
    hash.getSelectorFromName('vote'),
    voteCalldataHex.length,
    ...voteCalldataHex,
  ];
  console.log(calldata);

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
