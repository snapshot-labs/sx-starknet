import dotenv from 'dotenv';
dotenv.config();
import { task } from 'hardhat/config';
import { HardhatUserConfig } from 'hardhat/types';
import '@shardlabs/starknet-hardhat-plugin';
import '@typechain/hardhat';
import '@nomicfoundation/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-etherscan';
import '@nomicfoundation/hardhat-network-helpers';
import '@nomicfoundation/hardhat-foundry';

task('accounts', 'Prints the list of accounts', async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(await account.getAddress());
  }
});

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.6.12',
        settings: {
          optimizer: {
            enabled: true,
            runs: 10,
          },
        },
      },
      {
        version: '0.8.19',
        settings: {
          optimizer: {
            enabled: true,
            runs: 10,
          },
        },
      },
    ],
  },
  networks: {
    ethereumLocal: {
      url: 'http://127.0.0.1:8545/',
      chainId: 31337,
    },
    starknetLocal: {
      url: 'http://127.0.0.1:5050',
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  starknet: {
    scarbCommand: 'scarb',
    network: 'starknetLocal',
    recompile: false,
    venv: 'active',
    requestTimeout: 90_000,
  },
  paths: {
    starknetSources: './starknet',
    sources: 'ethereum/src/',
    tests: './starknet/test',
    cairoPaths: ['starknet/src/'],
  },
};

export default config;
