import fetch from 'cross-fetch';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { ethers } from 'ethers';
import { utils } from '@snapshot-labs/sx';
import {  defaultProvider, Account, ec, hash } from 'starknet';
import { domain, Propose, proposeTypes } from '../test/shared/types';
import { hexPadRight, getRSVFromSig } from '../test/shared/ethSigUtils';
import { PROPOSE_SELECTOR } from '../test/shared/constants';

async function main() {
  global.fetch = fetch;

  const starkAccount = new Account(
    defaultProvider,
    process.env.ARGENT_X_ADDRESS!,
    ec.getKeyPair(process.env.ARGENT_X_PK!)
  );
  const ethAccount = new ethers.Wallet(process.env.ETH_PK_1!);

  const spaceAddress = BigInt('0x5a1f0ec4b0c98eb8306b30aa2ec124381757ad80bbf5c6ebfe411b7a17a54b4');
  const votingStrategies = [
    BigInt('0x563633cb3ddcfd92651470d6f954ae9e03cca5a9d1a9c31ff24cc58331d4e1'),
  ];
  const userVotingStrategyParams: bigint[][] = [[]];
  const metadataUri = utils.strings.strToShortStringArr(
    'Hello and welcome to Snapshot X. This is the future of governance.'
  );

  // Single slot proof stuff, removed for now. Instead we use vanilla voting strategy
  // const block = JSON.parse(fs.readFileSync('./test/data/blockGoerli.json').toString());
  // const proofs = JSON.parse(fs.readFileSync('./test/data/proofsGoerli.json').toString());
  // const proofInputs: utils.storageProofs.ProofInputs = utils.storageProofs.getProofInputs(
  //   block.number,
  //   proofs
  // );
  // const processBlockInputs: utils.storageProofs.ProcessBlockInputs =
  //   utils.storageProofs.getProcessBlockInputs(block);

  const userVotingParamsAll1 = [[]];
  const executionStrategy = BigInt(
    '0x651fd70ebed45e2433d2db741806a354e9b977bfc12fa6f17369ce2bd8f58e2'
  );
  const executionParams = [BigInt(1)]; // Random params
  const executionParamsStrings: string[] = executionParams.map((x) => x.toString(16));
  const executionHash = hash.computeHashOnElements(executionParamsStrings);
  const proposerEthAddress = ethAccount.address;
  const proposeCalldata = utils.encoding.getProposeCalldata(
    proposerEthAddress,
    metadataUri,
    executionStrategy,
    votingStrategies,
    userVotingStrategyParams,
    executionParams
  );

  const salt = utils.splitUint256.SplitUint256.fromHex(
    utils.bytes.bytesToHex(ethers.utils.randomBytes(4))
  );  const executionHashStr = hexPadRight(executionHash);
  const message: Propose = {
    salt: Number(salt.toHex()),
    space: hexPadRight('0x' + spaceAddress.toString(16)),
    executionHash: executionHashStr,
  };
  const sig = await ethAccount._signTypedData(domain, proposeTypes, message);
  const { r, s, v } = getRSVFromSig(sig);

  const calldata = [
    r.low,
    r.high,
    s.low,
    s.high,
    v,
    salt.low,
    salt.high,
    spaceAddress,
    PROPOSE_SELECTOR,
    proposeCalldata.length,
    ...proposeCalldata,
  ];
  const calldataHex = calldata.map((x) => '0x' + x.toString(16));

  const { transaction_hash: txHash } = await starkAccount.execute(
    {
      contractAddress: '0x2e9bba3766cd43886605fcb0e1273c6c74a34e1cb0855f1138e6998e24c9220',
      entrypoint: 'authenticate',
      calldata: calldataHex,
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
