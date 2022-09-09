import fs from 'fs';
import fetch from 'cross-fetch';
import { defaultProvider, Account, ec, hash } from 'starknet';
import { utils } from '@snapshot-labs/sx';
import { ethers } from 'ethers';

async function main() {
  global.fetch = fetch;

  const provider = new ethers.providers.JsonRpcProvider(process.env.GOERLI_NODE_URL);
  const ethAccount = new ethers.Wallet(process.env.ETH_PK_1!, provider);

  const deployment = JSON.parse(fs.readFileSync('./deployments/goerli2.json').toString());
  const spaceAddress = deployment.space.address;

  const goerliChainId = 5;
  const zodiacModuleAddress = '0xa88f72e92cc519d617b684F8A78d3532E7bb61ca';
  const tx1: utils.encoding.MetaTransaction = {
    to: '0x2842c82E20ab600F443646e1BC8550B44a513D82',
    value: ethers.utils.parseEther('0.01').toHexString(),
    data: '0x',
    operation: 0,
    nonce: 0,
  };

  // const tx1: utils.encoding.MetaTransaction = {
  //   to: '0x2842c82E20ab600F443646e1BC8550B44a513D82',
  //   value: '0x',
  //   data: '0x',
  //   operation: 0,
  //   nonce: 9,
  // };

  const { executionHash, txHashes } = utils.encoding.createExecutionHash(
    [tx1],
    zodiacModuleAddress,
    goerliChainId
  );
  console.log(txHashes);
  const executionHashSplit = utils.splitUint256.SplitUint256.fromHex(executionHash);

  const zodiacModuleInterface = new ethers.utils.Interface(
    fs
      .readFileSync(
        './abi/contracts/ethereum/ZodiacModule/SnapshotXL1Executor.sol/SnapshotXL1Executor.json'
      )
      .toString()
  );
  const zodiacModule = new ethers.Contract(zodiacModuleAddress, zodiacModuleInterface, ethAccount);
  const proposalOutcome = 1;
  // const t = await zodiacModule.receiveProposal(spaceAddress, proposalOutcome, executionHashSplit.low, executionHashSplit.high, txHashes);
  // console.log(t);
  await zodiacModule.executeProposalTx(
    1,
    '0x2842c82E20ab600F443646e1BC8550B44a513D82',
    ethers.utils.parseEther('0.01').toHexString(),
    '0x',
    0
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
