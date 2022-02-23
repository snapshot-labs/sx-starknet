import dotenv from 'dotenv';
dotenv.config();
import { task } from 'hardhat/config';
import { HardhatUserConfig } from 'hardhat/types';
import '@shardlabs/starknet-hardhat-plugin';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import 'hardhat-gas-reporter';
import '@nomiclabs/hardhat-etherscan';
import 'solidity-coverage';

//const MNEMONIC = process.env.MNEMONIC || '';
//const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || '';
const INFURA_API_KEY = process.env.INFURA_API_KEY || '';
//const ALCHEMY_KEY = process.env.ALCHEMY_KEY || '';
const GOERLI_PRIVATE_KEY = process.env.GOERLI_PRIVATE_KEY || '0x1111111111111111111111111111111111111111111111111111111111111111';
const GOERLI_PRIVATE_KEY2 = process.env.GOERLI_PRIVATE_KEY2 || '0x1111111111111111111111111111111111111111111111111111111111111111';

task('accounts', 'Prints the list of accounts and balances', async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(await account.getAddress(), (await account.getBalance()).toString());
  }
});

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 10,
          }
        }
      },
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 10,
          }
        }
      }
    ],
  },
  networks: {
    goerli: {
      url: 'https://goerli.infura.io/v3/' + INFURA_API_KEY,
      accounts: [GOERLI_PRIVATE_KEY, GOERLI_PRIVATE_KEY2],
    },
    devnet: {
      url: 'http://localhost:8545',
    },
    starknetDevnet: {
      url: 'http://localhost:5000/',
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: 'USD',
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  mocha: {
    starknetNetwork: 'alpha-goerli',
    timeout: 240000,
  },
  cairo: {
    venv: process.env.VIRTUAL_ENV,
  },
};

export default config;
