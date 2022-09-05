import fs from 'fs';
import fetch from 'cross-fetch';
import { defaultProvider, Account, ec, hash } from 'starknet';
import { utils } from '@snapshot-labs/sx';
import { ethers } from 'ethers';

async function main() {
  global.fetch = fetch;

  const starkAccount = new Account(
    defaultProvider,
    process.env.ARGENT_X_ADDRESS!,
    ec.getKeyPair(process.env.ARGENT_X_PK!)
  );

  const provider = new ethers.providers.JsonRpcProvider(process.env.GOERLI_NODE_URL);
  const ethAccount = new ethers.Wallet(process.env.ETH_PK_1!, provider);

  const deployment = JSON.parse(fs.readFileSync('./deployments/goerli2.json').toString());
  const spaceAddress = deployment.space.address;

  const proposalId = '0x3';
  const goerliChainId = 5;
  const zodiacModuleAddress = '0x66072142ed77472728a146F00f137982e72F42Dc';
  const tx1: utils.encoding.MetaTransaction = {
    to: '0x2842c82E20ab600F443646e1BC8550B44a513D82',
    value: ethers.utils.parseEther('0.01').toHexString(),
    data: '0x',
    operation: 0,
    nonce: 0,
  };

  const { executionHash, txHashes } = utils.encoding.createExecutionHash(
    [tx1],
    zodiacModuleAddress,
    goerliChainId
  );
  const executionHashSplit = utils.splitUint256.SplitUint256.fromHex(executionHash);
  const executionParams = [zodiacModuleAddress, executionHashSplit.low, executionHashSplit.high];

  const { transaction_hash: txHash } = await starkAccount.execute(
    {
      contractAddress: spaceAddress,
      entrypoint: 'finalize_proposal',
      calldata: [proposalId, executionParams.length, ...executionParams],
    },
    undefined,
    { maxFee: '857400005301800' }
  );
  console.log('Waiting for confirmation, transaction hash: ', txHash);
  await defaultProvider.waitForTransaction(txHash);
  console.log('---- PROPOSAL FINALIZED ----');

  // const zodiacModuleInterface = new ethers.utils.Interface(
  //   fs
  //     .readFileSync(
  //       './abi/contracts/ethereum/ZodiacModule/SnapshotXL1Executor.sol/SnapshotXL1Executor.json'
  //     )
  //     .toString()
  // );
  // const zodiacModule = new ethers.Contract(
  //   zodiacModuleAddress,
  //   zodiacModuleInterface,
  //   ethAccount
  // );
  // const proposalOutcome = 1;
  // zodiacModule.receiveProposal(spaceAddress, proposalOutcome, executionHashSplit.low, executionHashSplit.high, txHashes)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
