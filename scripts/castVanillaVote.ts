import fetch from 'cross-fetch';
import fs from 'fs';
import { ethers } from 'ethers';
import { utils } from '@snapshot-labs/sx';
import { defaultProvider, Account, ec } from 'starknet';
import { VOTE_SELECTOR } from '../test/shared/constants';

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
  const spaceAddress = deployment.space.address;

  const proposalId = '0x3';
  const choice = utils.choice.Choice.FOR;
  const usedVotingStrategies = ['0x0']; // Vanilla voting strategy is index 0
  const userVotingStrategyParams = [[]];
  const voterEthAddress = ethAccount.address;
  const voteCalldata = utils.encoding.getVoteCalldata(
    voterEthAddress,
    proposalId,
    choice,
    usedVotingStrategies,
    userVotingStrategyParams
  );

  const { transaction_hash: txHash } = await starkAccount.execute(
    {
      contractAddress: vanillaAuthenticatorAddress,
      entrypoint: 'authenticate',
      calldata: [spaceAddress, VOTE_SELECTOR, voteCalldata.length, ...voteCalldata],
    },
    undefined,
    { maxFee: '857400005301800' }
  );
  console.log('Waiting for confirmation, transaction hash: ', txHash);
  await defaultProvider.waitForTransaction(txHash);
  console.log('---- VOTE CAST ----');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
