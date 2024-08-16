import dotenv from 'dotenv';
dotenv.config();
import { task } from 'hardhat/config';
import { HardhatUserConfig } from 'hardhat/types';
import 'starknet';
import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-network-helpers';
import '@nomicfoundation/hardhat-foundry';
import '@openzeppelin/hardhat-upgrades';

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
        version: '0.8.24',
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
    tests: './tests',
    cairoPaths: ['starknet/src/'],
  },
};

export default config;
