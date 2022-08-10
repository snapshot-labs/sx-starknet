import fetch from 'cross-fetch';
import fs from 'fs';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { ethers } from 'ethers';
import { utils } from '@snapshot-labs/sx';
import { defaultProvider, Account, ec, hash } from 'starknet';
import { domain, Propose, proposeTypes } from '../test/shared/types';
import { hexPadRight, getRSVFromSig } from '../test/shared/ethSigUtils';
import { PROPOSE_SELECTOR } from '../test/shared/constants';

async function main() {
  global.fetch = fetch;

  const fossilFactRegistryAddress =
    '0x363108ac1521a47b4f7d82f8ba868199bc1535216bbedfc1b071ae93cc406fd';
  const fossilL1HeadersStoreAddress =
    '0x6ca3d25e901ce1fff2a7dd4079a24ff63ca6bbf8ba956efc71c1467975ab78f';

  const starkAccount = new Account(
    defaultProvider,
    process.env.ARGENT_X_ADDRESS!,
    ec.getKeyPair(process.env.ARGENT_X_PK!)
  );
  const ethAccount = new ethers.Wallet(process.env.ETH_PK_1!);

  //   Single slot proof stuff, removed for now. Instead we use vanilla voting strategy
  const block = JSON.parse(fs.readFileSync('./test/data/blockGoerli.json').toString());
  // const proofs = JSON.parse(fs.readFileSync('./test/data/proofsGoerli.json').toString());
  // const proofInputs: utils.storageProofs.ProofInputs = utils.storageProofs.getProofInputs(
  //   block.number,
  //   proofs
  // );
  const processBlockInputs: utils.storageProofs.ProcessBlockInputs =
    utils.storageProofs.getProcessBlockInputs(block);

  // const calldata = [
  //   processBlockInputs.blockOptions,
  //   processBlockInputs.blockNumber,
  //   processBlockInputs.headerInts.bytesLength,
  //   processBlockInputs.headerInts.values.length,
  //   ...processBlockInputs.headerInts.values,
  // ];
  // const calldataHex = calldata.map((x) => '0x' + x.toString(16));
  // const { transaction_hash: txHash } = await starkAccount.execute(
  //   {
  //     contractAddress: fossilL1HeadersStoreAddress,
  //     entrypoint: 'process_block',
  //     calldata: calldataHex,
  //   },
  //   undefined,
  //   { maxFee: '857400005301800' }
  // );
  // console.log(txHash);

  // const calldata = [
  //   proofInputs.accountOptions,
  //   proofInputs.blockNumber,
  //   proofInputs.ethAddress.values[0],
  //   proofInputs.ethAddress.values[1],
  //   proofInputs.ethAddress.values[2],
  //   proofInputs.accountProofSizesBytes.length,
  //   ...proofInputs.accountProofSizesBytes,
  //   proofInputs.accountProofSizesWords.length,
  //   ...proofInputs.accountProofSizesWords,
  //   proofInputs.accountProof.length,
  //   ...proofInputs.accountProof,
  // ];
  // const calldataHex = calldata.map((x) => '0x' + x.toString(16));
  // console.log(calldataHex);
  // const { transaction_hash: txHash } = await starkAccount.execute(
  //   {
  //     contractAddress: fossilFactRegistryAddress,
  //     entrypoint: 'prove_account',
  //     calldata: calldataHex,
  //   },
  //   undefined,
  //   { maxFee: '857400005301800' }
  // );
  // console.log(txHash);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
