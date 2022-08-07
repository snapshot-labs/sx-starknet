// eslint-disable-next-line
const Web3 = require('web3');
import fs from 'fs';
import ethers from 'ethers';
import http from 'http';

async function main() {
  const web3 = new Web3(process.env.GOERLI_NODE_URL!);
  const block = await web3.eth.getBlock(process.env.BLOCK_NUMBER);
  fs.writeFileSync('./test/data/blockGoerli.json', JSON.stringify(block));

  const accessList = await web3.eth.createAccessList({
    from: '0x2842c82E20ab600F443646e1BC8550B44a513D82',
    data: '0x70a082310000000000000000000000002842c82E20ab600F443646e1BC8550B44a513D82',
    gas: '0x3d0900',
    gasPrice: '0x0',
    to: '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6',
  });
  const accessList2 = await web3.eth.createAccessList({
    from: '0x2842c82E20ab600F443646e1BC8550B44a513D82',
    data: '0x70a082310000000000000000000000006015a04aFab2C317Aa02557cc35852e4C9B62c40',
    gas: '0x3d0900',
    gasPrice: '0x0',
    to: '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6',
  });
  const proof = await web3.eth.getProof(
    '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6',
    [accessList.accessList[0].storageKeys[0], accessList2.accessList[0].storageKeys[0]],
    process.env.BLOCK_NUMBER
  );
  // // const provider = new ethers.providers.JsonRpcProvider(process.env.GOERLI_NODE_URL!);
	// const provider = new ethers.providers.AlchemyProvider("homestead", "OAHlljqbWeNIlLGh1noXrhkf7sHHYPmx");

  // const proof2 = await provider.getProof({
  //   address: '0x7e5814a',
  // keys: ["0x56e81f,0x283s34"],
  // tag: 'latest',
  // });
  //   console.log(proof2);

  const options = {
    host: 'https://eth-mainnet.alchemyapi.io',
    path: '/v2/OAHlljqbWeNIlLGh1noXrhkf7sHHYPmx',
    method: 'POST',
    headers: { Content-Type: "application/json" },
    data: 
  };
  fs.writeFileSync('./test/data/proofsGoerli.json', JSON.stringify(proof));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
