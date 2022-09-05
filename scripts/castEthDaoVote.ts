import fetch from 'cross-fetch';
import fs from 'fs';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { ethers } from 'ethers';
import { utils } from '@snapshot-labs/sx';
import { defaultProvider, Account, ec, hash } from 'starknet';
import { domain, Vote, voteTypes } from '../test/shared/types';
import { VOTE_SELECTOR } from '../test/shared/constants';

async function main() {
  global.fetch = fetch;

  const starkAccount = new Account(
    defaultProvider,
    process.env.ARGENT_X_ADDRESS!,
    ec.getKeyPair(process.env.ARGENT_X_PK!)
  );
  const ethAccount = new ethers.Wallet(process.env.ETH_PK_2!);

  const deployment = JSON.parse(fs.readFileSync('./deployments/goerli2.json').toString());
  const ethSigAuthenticatorAddress = deployment.space.authenticators.ethSig;
  const spaceAddress = deployment.space.address;

  const proposalId = '0x1';
  const choice = utils.choice.Choice.FOR;
  const usedVotingStrategies = ['0x1']; // Goerli WETH balance voting strategy is index 1
  const block = JSON.parse(fs.readFileSync('./test/data/blockGoerli.json').toString());
  const proofs = JSON.parse(fs.readFileSync('./test/data/proofsGoerli.json').toString());
  const proofInputs: utils.storageProofs.ProofInputs = utils.storageProofs.getProofInputs(
    block.number,
    proofs
  );
  const userVotingStrategyParams = [proofInputs.storageProofs[1]];
  const voterEthAddress = ethAccount.address;
  const voteCalldata = utils.encoding.getVoteCalldata(
    voterEthAddress,
    proposalId,
    choice,
    usedVotingStrategies,
    userVotingStrategyParams
  );

  const salt = utils.splitUint256.SplitUint256.fromHex(
    utils.bytes.bytesToHex(ethers.utils.randomBytes(4))
  );

  const message: Vote = {
    space: utils.encoding.hexPadRight(spaceAddress),
    voterAddress: utils.encoding.hexPadRight(voterEthAddress),
    proposal: BigInt(proposalId).toString(16),
    choice: utils.choice.Choice.FOR,
    usedVotingStrategiesHash: utils.encoding.hexPadRight(
      hash.computeHashOnElements(usedVotingStrategies)
    ),
    userVotingStrategyParamsFlatHash: utils.encoding.hexPadRight(
      hash.computeHashOnElements(utils.encoding.flatten2DArray(userVotingStrategyParams))
    ),
    salt: salt.toHex(),
  };
  const sig = await ethAccount._signTypedData(domain, voteTypes, message);
  const { r, s, v } = utils.encoding.getRSVFromSig(sig);

  const { transaction_hash: txHash } = await starkAccount.execute(
    {
      contractAddress: ethSigAuthenticatorAddress,
      entrypoint: 'authenticate',
      calldata: [
        r.low,
        r.high,
        s.low,
        s.high,
        v,
        salt.low,
        salt.high,
        spaceAddress,
        VOTE_SELECTOR,
        voteCalldata.length,
        ...voteCalldata,
      ],
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
