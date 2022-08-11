import fs from 'fs';
import axios from 'axios';
import { utils } from '@snapshot-labs/sx';

async function main() {
  // The target block number.
  const blockNumber = '0x709C42';

  // The address of the contract we are proving storage values from.
  // This example is the Goerli WETH ERC20 contract address.
  const contractAddress = '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6';

  // Voter/Proposer addresses that we need to generate storage proofs for.
  const addresses = [
    '0x2842c82E20ab600F443646e1BC8550B44a513D82',
    '0x6015a04aFab2C317Aa02557cc35852e4C9B62c40',
  ];

  // The index of the mapping in then contract that we are proving storage values from.
  // This example is the index of the balances[] mapping in the Goerli WETH ERC20 contract.
  const slotIndex = '0x3';

  // Generating the slot keys from the addresses and slot index.
  const slotKeys = addresses.map(function (address) {
    return utils.encoding.getSlotKey(address, slotIndex);
  });

  // Retreiving the block data for the target block number.
  const block = await axios({
    url: process.env.GOERLI_NODE_URL!,
    method: 'POST',
    data: { jsonrpc: '2.0', method: 'eth_getBlockByNumber', params: [blockNumber, false], id: 1 },
  }).then(function (response) {
    fs.writeFileSync('./test/data/blockGoerli.json', JSON.stringify(response.data.result));
  });

  // Retreiving the account and storage proofs for the contract and slot keys specified at the target block number.
  const proof = await axios({
    url: process.env.GOERLI_NODE_URL!,
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    data: {
      jsonrpc: '2.0',
      method: 'eth_getProof',
      params: [contractAddress, slotKeys, blockNumber],
      id: 1,
    },
  }).then(function (response) {
    fs.writeFileSync('./test/data/proofsGoerli.json', JSON.stringify(response.data.result));
  });
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
