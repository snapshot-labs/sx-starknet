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

  const spaceAddress = '0x5ad4bd1ca422953ac845ac7915ddfa93fe3fecec0ed8c86db5e294b0e18c9bd';
  const proposalId = '0x2';
  const choice = utils.choice.Choice.FOR;
  const authenticatorAddress = '0x77e6ce69756aec5994314726b71a7ae95ffb15180711e481d71b5595b70a468';
  const votingStrategies = ['0x59b3695eb816a55f8251b6f7dd254798f58e95119e031caed8e02cdbacbca84'];
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
    votingStrategies,
    userVotingStrategyParams
  );

  const salt = utils.splitUint256.SplitUint256.fromHex(
    utils.bytes.bytesToHex(ethers.utils.randomBytes(4))
  );
  const message: Vote = {
    salt: Number(salt.toHex()),
    space: utils.encoding.hexPadRight(spaceAddress),
    proposal: Number(proposalId),
    choice: choice,
  };
  const sig = await ethAccount._signTypedData(domain, voteTypes, message);
  const { r, s, v } = utils.encoding.getRSVFromSig(sig);

  // const { transaction_hash: txHash } = await starkAccount.execute(
  //   {
  //     contractAddress: authenticatorAddress,
  //     entrypoint: 'authenticate',
  //     calldata: [
  //       r.low,
  //       r.high,
  //       s.low,
  //       s.high,
  //       v,
  //       salt.low,
  //       salt.high,
  //       spaceAddress,
  //       VOTE_SELECTOR,
  //       voteCalldata.length,
  //       ...voteCalldata,
  //     ],
  //   },
  //   undefined,
  //   { maxFee: '857400005301800' }
  // );
  // console.log('Waiting for confirmation, transaction hash: ', txHash);
  // await defaultProvider.waitForTransaction(txHash);
  // console.log('---- VOTE CAST ----');

  const out = await starkAccount.estimateFee({
    contractAddress: authenticatorAddress,
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
  });
  console.log(out);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
