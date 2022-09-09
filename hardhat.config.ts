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
import 'hardhat-abi-exporter';

// const chainIds = {
//   ganache: 1337,
//   goerli: 5,
//   hardhat: 31337,
//   kovan: 42,
//   mainnet: 1,
//   rinkeby: 4,
//   ropsten: 3,
// };

// const MNEMONIC = process.env.MNEMONIC || '';
// const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || '';
// const INFURA_API_KEY = process.env.INFURA_API_KEY || '';
// const ALCHEMY_KEY = process.env.ALCHEMY_KEY || '';

task('accounts', 'Prints the list of accounts', async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(await account.getAddress());
  }
});

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.9',
    settings: {
      optimizer: {
        enabled: true,
        runs: 10,
      },
    },
  },
  networks: {
    ropsten: {
      url: process.env.ROPSTEN_URL || '',
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    goerli: {
      url: process.env.GOERLI_NODE_URL || '',
      accounts: process.env.ETH_PK_1 !== undefined ? [process.env.ETH_PK_1] : [],
    },
    ethereumLocal: {
      url: 'http://localhost:8545',
      chainId: 31337,
    },
    starknetLocal: {
      url: 'http://localhost:8000',
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: 'USD',
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  starknet: {
    venv: 'active',
    network: 'starknetLocal',
  },
  paths: {
    cairoPaths: ['./contracts/starknet/fossil/contracts'],
  },
};

export default config;
