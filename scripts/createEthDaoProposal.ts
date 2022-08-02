import fetch from 'cross-fetch';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { ethers } from 'ethers';
import { utils } from '@snapshot-labs/sx';
import { defaultProvider, Account, ec, hash } from 'starknet';
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

  const spaceAddress = BigInt('0x047d4a40e6f80d3b28de7f09677a21681f0ff5f11633dd7ec8e86e48c7fe1ee0');
  const votingStrategies = [
    BigInt(
      '0x663aa290f8d650117bd0faa9d14bfc6cd9626b5210b21d2524ccabb751b0bc7'
    ),
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
    '0x79ef63495a9249d8c1174415c3c236d49dde3f1e8b6ef63cf9a0fd24c39934'
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
  );
  const executionHashStr = hexPadRight(executionHash);
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
  const authenticatorAddress = '0x4886e6e13e4af4e65149a1528c3ee0833ae22cf2764a493bad89061c72c8da6';
  const { transaction_hash: txHash } = await starkAccount.execute(
    {
      contractAddress: authenticatorAddress,
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
