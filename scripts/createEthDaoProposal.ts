import fetch from 'cross-fetch';
import fs from 'fs';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { ethers } from 'ethers';
import { utils } from '@snapshot-labs/sx';
import { defaultProvider, Account, ec, hash } from 'starknet';
import { domain, Propose, proposeTypes } from '../test/shared/types';
import { PROPOSE_SELECTOR } from '../test/shared/constants';

async function main() {
  global.fetch = fetch;

  const starkAccount = new Account(
    defaultProvider,
    process.env.ARGENT_X_ADDRESS!,
    ec.getKeyPair(process.env.ARGENT_X_PK!)
  );
  const ethAccount = new ethers.Wallet(process.env.ETH_PK_1!);

  const spaceAddress = '0x5ad4bd1ca422953ac845ac7915ddfa93fe3fecec0ed8c86db5e294b0e18c9bd';
  const authenticatorAddress = '0x77e6ce69756aec5994314726b71a7ae95ffb15180711e481d71b5595b70a468';
  const votingStrategies = ['0x59b3695eb816a55f8251b6f7dd254798f58e95119e031caed8e02cdbacbca84'];
  const metadataUri = 'Hello and welcome to Snapshot X. This is the future of governance.';
  const metadataUriInts = utils.intsSequence.IntsSequence.LEFromString(metadataUri);
  const block = JSON.parse(fs.readFileSync('./test/data/blockGoerli.json').toString());
  const proofs = JSON.parse(fs.readFileSync('./test/data/proofsGoerli.json').toString());
  const proofInputs: utils.storageProofs.ProofInputs = utils.storageProofs.getProofInputs(
    block.number,
    proofs
  );
  const userVotingStrategyParams = [proofInputs.storageProofs[0]];
  const executionStrategy = '0x56aabaa21efea14289fdc1df7d76d3b5df179d94dc8e9f937b9a9dd75eb101a';
  const executionParams = ['0x1']; // Random params
  const executionHash = hash.computeHashOnElements(executionParams);
  const proposerEthAddress = ethAccount.address;
  const proposeCalldata = utils.encoding.getProposeCalldata(
    proposerEthAddress,
    metadataUriInts,
    executionStrategy,
    votingStrategies,
    userVotingStrategyParams,
    executionParams
  );

  const salt = utils.splitUint256.SplitUint256.fromHex(
    utils.bytes.bytesToHex(ethers.utils.randomBytes(4))
  );
  const executionHashStr = utils.encoding.hexPadRight(executionHash);
  const message: Propose = {
    salt: Number(salt.toHex()),
    space: utils.encoding.hexPadRight(spaceAddress),
    metadataURI: metadataUri,
    executionHash: executionHashStr,
  };
  const sig = await ethAccount._signTypedData(domain, proposeTypes, message);
  const { r, s, v } = utils.encoding.getRSVFromSig(sig);

  const { transaction_hash: txHash } = await starkAccount.execute(
    {
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
        PROPOSE_SELECTOR,
        proposeCalldata.length,
        ...proposeCalldata,
      ],
    },
    undefined,
    { maxFee: '857400005301800' }
  );
  console.log('Waiting for confirmation, transaction hash: ', txHash);
  await defaultProvider.waitForTransaction(txHash);
  console.log('---- PROPOSAL CREATED ----');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
