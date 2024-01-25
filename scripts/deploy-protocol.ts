import fs from 'fs';
import dotenv from 'dotenv';
import { RpcProvider, Account, json, CallData } from 'starknet';

dotenv.config();

const network = process.env.STARKNET_NETWORK_URL || '';
const account_address = process.env.ADDRESS || '';
const account_pk = process.env.PK || '';

const starknetCommitAddress = process.env.STARKNET_COMMIT_ADDRESS || '';
const factsRegistryAddress = '0x014bf62fadb41d8f899bb5afeeb2da486fcfd8431852def56c5f10e45ae72765'; //process.env.FACTS_REGISTRY_ADDRESS || '';
const timestampRemappersAddress =
  '0x0050e1a1a352049b29103d8b42cf00f6faa2d5e88e94ed71962a1bfb24e5b0b2'; //process.env.TIMESTAMP_REMAPPERS_ADDRESS || '';

const SIGNED_MSG_NAME = 'sx-starknet';
const SIGNED_MSG_VERSION = '0.1.0';

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const vanillaAuthenticatorSierra = json.parse(
  fs.readFileSync('starknet/target/dev/sx_VanillaAuthenticator.sierra.json').toString('ascii'),
);
const vanillaAuthenticatorCasm = json.parse(
  fs.readFileSync('starknet/target/dev/sx_VanillaAuthenticator.casm.json').toString('ascii'),
);

const ethSigAuthenticatorSierra = json.parse(
  fs.readFileSync('starknet/target/dev/sx_EthSigAuthenticator.sierra.json').toString('ascii'),
);
const ethSigAuthenticatorCasm = json.parse(
  fs.readFileSync('starknet/target/dev/sx_EthSigAuthenticator.casm.json').toString('ascii'),
);

const ethTxAuthenticatorSierra = json.parse(
  fs.readFileSync('starknet/target/dev/sx_EthTxAuthenticator.sierra.json').toString('ascii'),
);
const ethTxAuthenticatorCasm = json.parse(
  fs.readFileSync('starknet/target/dev/sx_EthTxAuthenticator.casm.json').toString('ascii'),
);

const starkSigAuthenticatorSierra = json.parse(
  fs.readFileSync('starknet/target/dev/sx_StarkSigAuthenticator.sierra.json').toString('ascii'),
);
const starkSigAuthenticatorCasm = json.parse(
  fs.readFileSync('starknet/target/dev/sx_StarkSigAuthenticator.casm.json').toString('ascii'),
);

const starkTxAuthenticatorSierra = json.parse(
  fs.readFileSync('starknet/target/dev/sx_StarkTxAuthenticator.sierra.json').toString('ascii'),
);
const starkTxAuthenticatorCasm = json.parse(
  fs.readFileSync('starknet/target/dev/sx_StarkTxAuthenticator.casm.json').toString('ascii'),
);

const ethRelayerExecutionStrategySierra = json.parse(
  fs
    .readFileSync('starknet/target/dev/sx_EthRelayerExecutionStrategy.sierra.json')
    .toString('ascii'),
);
const ethRelayerExecutionStrategyCasm = json.parse(
  fs.readFileSync('starknet/target/dev/sx_EthRelayerExecutionStrategy.casm.json').toString('ascii'),
);

const noExecutionSimpleMajorityExecutionStrategySierra = json.parse(
  fs
    .readFileSync('starknet/target/dev/sx_NoExecutionSimpleMajorityExecutionStrategy.sierra.json')
    .toString('ascii'),
);
const noExecutionSimpleMajorityExecutionStrategyCasm = json.parse(
  fs
    .readFileSync('starknet/target/dev/sx_NoExecutionSimpleMajorityExecutionStrategy.casm.json')
    .toString('ascii'),
);

const vanillaProposalValidationStrategySierra = json.parse(
  fs
    .readFileSync('starknet/target/dev/sx_VanillaProposalValidationStrategy.sierra.json')
    .toString('ascii'),
);
const vanillaProposalValidationStrategyCasm = json.parse(
  fs
    .readFileSync('starknet/target/dev/sx_VanillaProposalValidationStrategy.casm.json')
    .toString('ascii'),
);

const propositionPowerProposalValidationStrategySierra = json.parse(
  fs
    .readFileSync('starknet/target/dev/sx_PropositionPowerProposalValidationStrategy.sierra.json')
    .toString('ascii'),
);
const propositionPowerProposalValidationStrategyCasm = json.parse(
  fs
    .readFileSync('starknet/target/dev/sx_PropositionPowerProposalValidationStrategy.casm.json')
    .toString('ascii'),
);

const vanillaVotingStrategySierra = json.parse(
  fs.readFileSync('starknet/target/dev/sx_VanillaVotingStrategy.sierra.json').toString('ascii'),
);

const vanillaVotingStrategyCasm = json.parse(
  fs.readFileSync('starknet/target/dev/sx_VanillaVotingStrategy.casm.json').toString('ascii'),
);

const erc20VotesVotingStrategySierra = json.parse(
  fs.readFileSync('starknet/target/dev/sx_ERC20VotesVotingStrategy.sierra.json').toString('ascii'),
);

const erc20VotesVotingStrategyCasm = json.parse(
  fs.readFileSync('starknet/target/dev/sx_ERC20VotesVotingStrategy.casm.json').toString('ascii'),
);

const merkleWhitelistVotingStrategySierra = json.parse(
  fs
    .readFileSync('starknet/target/dev/sx_MerkleWhitelistVotingStrategy.sierra.json')
    .toString('ascii'),
);
const merkleWhitelistVotingStrategyCasm = json.parse(
  fs
    .readFileSync('starknet/target/dev/sx_MerkleWhitelistVotingStrategy.casm.json')
    .toString('ascii'),
);

const OZVotesStorageProofVotingStrategySierra = json.parse(
  fs
    .readFileSync('starknet/target/dev/sx_OZVotesStorageProofVotingStrategy.sierra.json')
    .toString('ascii'),
);

const OZVotesStorageProofVotingStrategyCasm = json.parse(
  fs
    .readFileSync('starknet/target/dev/sx_OZVotesStorageProofVotingStrategy.casm.json')
    .toString('ascii'),
);

const factorySierra = json.parse(
  fs.readFileSync('starknet/target/dev/sx_Factory.sierra.json').toString('ascii'),
);
const factoryCasm = json.parse(
  fs.readFileSync('starknet/target/dev/sx_Factory.casm.json').toString('ascii'),
);

const spaceSierra = json.parse(
  fs.readFileSync('starknet/target/dev/sx_Space.sierra.json').toString('ascii'),
);
const spaceCasm = json.parse(
  fs.readFileSync('starknet/target/dev/sx_Space.casm.json').toString('ascii'),
);

async function main() {
  const provider = new RpcProvider({ nodeUrl: network });
  const account = new Account(provider, account_address, account_pk);
  const wait = 20000;
  let response;

  // Uncomment the following code in sections to deploy the contracts
  // Due to rate limiting, you cannot deploy all the contracts at once.

  response = await account.declareAndDeploy({
    contract: vanillaAuthenticatorSierra,
    casm: vanillaAuthenticatorCasm,
    constructorCalldata: CallData.compile({}),
  });

  const vanillaAuthenticatorAddress = response.deploy.contract_address;
  console.log('vanillaAuthenticatorAddress: ', vanillaAuthenticatorAddress);
  delay(wait);

  response = await account.declareAndDeploy({
    contract: ethSigAuthenticatorSierra,
    casm: ethSigAuthenticatorCasm,
    constructorCalldata: CallData.compile({}),
  });

  const ethSigAuthenticatorAddress = response.deploy.contract_address;
  console.log('ethSigAuthenticatorAddress: ', ethSigAuthenticatorAddress);
  delay(wait);

  response = await account.declareAndDeploy({
    contract: ethTxAuthenticatorSierra,
    casm: ethTxAuthenticatorCasm,
    constructorCalldata: CallData.compile({
      starknet_commit_address: starknetCommitAddress,
    }),
  });

  const ethTxAuthenticatorAddress = response.deploy.contract_address;
  console.log('ethTxAuthenticatorAddress: ', ethTxAuthenticatorAddress);

  delay(wait);

  response = await account.declareAndDeploy({
    contract: starkSigAuthenticatorSierra,
    casm: starkSigAuthenticatorCasm,
    constructorCalldata: CallData.compile({ name: SIGNED_MSG_NAME, version: SIGNED_MSG_VERSION }),
  });

  const starkSigAuthenticatorAddress = response.deploy.contract_address;
  console.log('starkSigAuthenticatorAddress: ', starkSigAuthenticatorAddress);
  delay(wait);

  response = await account.declareAndDeploy({
    contract: starkTxAuthenticatorSierra,
    casm: starkTxAuthenticatorCasm,
    constructorCalldata: CallData.compile({}),
  });

  const starkTxAuthenticatorAddress = response.deploy.contract_address;
  console.log('starkTxAuthenticatorAddress: ', starkTxAuthenticatorAddress);
  delay(wait);

  response = await account.declareAndDeploy({
    contract: ethRelayerExecutionStrategySierra,
    casm: ethRelayerExecutionStrategyCasm,
    constructorCalldata: CallData.compile({}),
  });

  const ethRelayerExecutionStrategyAddress = response.deploy.contract_address;
  console.log('ethRelayerExecutionStrategyAddress: ', ethRelayerExecutionStrategyAddress);
  delay(wait);

  response = await account.declareAndDeploy({
    contract: noExecutionSimpleMajorityExecutionStrategySierra,
    casm: noExecutionSimpleMajorityExecutionStrategyCasm,
    constructorCalldata: CallData.compile({}),
  });

  const noExecutionSimpleMajorityExecutionStrategyAddress = response.deploy.contract_address;
  console.log(
    'noExecutionSimpleMajorityExecutionStrategyAddress: ',
    noExecutionSimpleMajorityExecutionStrategyAddress,
  );
  delay(wait);

  response = await account.declareAndDeploy({
    contract: vanillaProposalValidationStrategySierra,
    casm: vanillaProposalValidationStrategyCasm,
    constructorCalldata: CallData.compile({}),
  });

  const vanillaProposalValidationStrategyAddress = response.deploy.contract_address;
  console.log(
    'vanillaProposalValidationStrategyAddress: ',
    vanillaProposalValidationStrategyAddress,
  );
  delay(wait);

  response = await account.declareAndDeploy({
    contract: propositionPowerProposalValidationStrategySierra,
    casm: propositionPowerProposalValidationStrategyCasm,
    constructorCalldata: CallData.compile({}),
  });

  const propositionPowerProposalValidationStrategyAddress = response.deploy.contract_address;
  console.log(
    'propositionPowerProposalValidationStrategyAddress: ',
    propositionPowerProposalValidationStrategyAddress,
  );
  delay(wait);

  response = await account.declareAndDeploy({
    contract: vanillaVotingStrategySierra,
    casm: vanillaVotingStrategyCasm,
    constructorCalldata: CallData.compile({}),
  });

  const vanillaVotingStrategyAddress = response.deploy.contract_address;
  console.log('vanillaVotingStrategyAddress: ', vanillaVotingStrategyAddress);

  response = await account.declareAndDeploy({
    contract: erc20VotesVotingStrategySierra,
    casm: erc20VotesVotingStrategyCasm,
    constructorCalldata: CallData.compile({}),
  });

  const erc20VotesVotingStrategyAddress = response.deploy.contract_address;
  console.log('erc20VotesVotingStrategyAddress: ', erc20VotesVotingStrategyAddress);
  delay(wait);

  response = await account.declareAndDeploy({
    contract: merkleWhitelistVotingStrategySierra,
    casm: merkleWhitelistVotingStrategyCasm,
    constructorCalldata: CallData.compile({}),
  });

  const merkleWhitelistVotingStrategyAddress = response.deploy.contract_address;
  console.log('merkleWhitelistVotingStrategyAddress: ', merkleWhitelistVotingStrategyAddress);
  delay(wait);

  response = await account.declareAndDeploy({
    contract: OZVotesStorageProofVotingStrategySierra,
    casm: OZVotesStorageProofVotingStrategyCasm,
    constructorCalldata: CallData.compile({
      timestamp_remappers: timestampRemappersAddress,
      facts_registry: factsRegistryAddress,
    }),
  });

  const OZVotesStorageProofVotingStrategy = response.deploy.contract_address;
  console.log('OZVotesStorageProofVotingStrategy: ', OZVotesStorageProofVotingStrategy);

  response = await account.declareAndDeploy({
    contract: factorySierra,
    casm: factoryCasm,
    constructorCalldata: CallData.compile({}),
  });

  const factoryAddress = response.deploy.contract_address;
  console.log('factoryAddress: ', factoryAddress);

  response = await account.declareAndDeploy({
    contract: spaceSierra,
    casm: spaceCasm,
    constructorCalldata: CallData.compile({}),
  });

  const spaceAddress = response.deploy.contract_address;
  console.log('spaceAddress: ', spaceAddress);
}

main();