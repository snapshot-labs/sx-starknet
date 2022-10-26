import fetch from 'cross-fetch';
import fs from 'fs';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { ethers } from 'ethers';
import { utils } from '@snapshot-labs/sx';
import { Provider, defaultProvider, Account, ec, hash } from 'starknet';
import { domain, Propose, proposeTypes } from '../test/shared/types';
import { PROPOSE_SELECTOR } from '../test/shared/constants';

async function main() {
  global.fetch = fetch;

  const provider = process.env.STARKNET_PROVIDER_BASE_URL === undefined ?
  defaultProvider :
    new Provider({
      sequencer: {
        baseUrl: process.env.STARKNET_PROVIDER_BASE_URL!,
        feederGatewayUrl: 'feeder_gateway',
        gatewayUrl: 'gateway',
      }, 
  });

  const starkAccount = new Account(
    provider,
    process.env.ACCOUNT_ADDRESS!,
    ec.getKeyPair(process.env.ACCOUNT_PRIVATE_KEY!)
  );
  const ethAccount = new ethers.Wallet(process.env.ETH_PK_1!);

  const deployment = JSON.parse(fs.readFileSync('./deployments/goerli5.json').toString());
  const ethSigAuthenticatorAddress = deployment.spaces[1].authenticators.ethSig;
  const vanillaExecutionStrategyAddress = deployment.spaces[1].executionStrategies.vanilla;
  const spaceAddress = deployment.spaces[1].address;

  const usedVotingStrategies = ['0x0'];
  const metadataUri = 'Hello and welcome to Snapshot X. This is the future of governance.';
  const metadataUriInts = utils.intsSequence.IntsSequence.LEFromString(metadataUri);
  // const block = JSON.parse(fs.readFileSync('./test/data/blockGoerli.json').toString());
  // const proofs = JSON.parse(fs.readFileSync('./test/data/proofsGoerli.json').toString());
  // const proofInputs: utils.storageProofs.ProofInputs = utils.storageProofs.getProofInputs(
  //   block.number,
  //   proofs
  // );
  // const userVotingStrategyParams = [proofInputs.storageProofs[0]];
  const userVotingStrategyParams: string[][] = [[]];
  const executionStrategy = vanillaExecutionStrategyAddress;
  const executionParams = ['0x1']; // Random params
  const executionHash = hash.computeHashOnElements(executionParams);
  const proposerEthAddress = ethAccount.address;
  const proposeCalldata = utils.encoding.getProposeCalldata(
    proposerEthAddress,
    metadataUriInts,
    executionStrategy,
    usedVotingStrategies,
    userVotingStrategyParams,
    executionParams
  );

  const salt = utils.splitUint256.SplitUint256.fromHex(
    utils.bytes.bytesToHex(ethers.utils.randomBytes(6))
  );

  const message: Propose = {
    authenticator: utils.encoding.hexPadRight(ethSigAuthenticatorAddress),
    space: utils.encoding.hexPadRight(spaceAddress),
    author: proposerEthAddress,
    metadata_uri: metadataUri,
    executor: utils.encoding.hexPadRight(vanillaExecutionStrategyAddress),
    execution_hash: utils.encoding.hexPadRight(executionHash),
    strategies_hash: utils.encoding.hexPadRight(
      hash.computeHashOnElements(usedVotingStrategies)
    ),
    strategies_params_hash: utils.encoding.hexPadRight(
      hash.computeHashOnElements(utils.encoding.flatten2DArray(userVotingStrategyParams))
    ),
    salt: salt.toHex(),
  };
  const sig = await ethAccount._signTypedData(domain, proposeTypes, message);
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
        PROPOSE_SELECTOR,
        proposeCalldata.length,
        ...proposeCalldata,
      ],
    },
    undefined,
    { maxFee: '55818000000000000000' }
  );
  console.log('Waiting for confirmation, transaction hash: ', txHash);
  await provider.waitForTransaction(txHash);
  console.log('---- PROPOSAL CREATED ----');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
