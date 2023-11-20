import fs from 'fs';
import { RpcProvider, Account, ec, json, CallData } from 'starknet';

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
  const account_address = '0x0071399180e89305007c030004d68ebbed03e2b6d780de66ba36c64630acca52';
  const account_pk = '0x2587FB9D2FE799E759769D7DB115018C4FDF8F0F4047AE5E0A6C17B56B8B224';
  const network = 'https://starknet-goerli.g.alchemy.com/v2/2rHwIyOetFjUsdM4M_SBXpj1ejkck6lr';
  const provider = new RpcProvider({ nodeUrl: network });
  const account = new Account(provider, account_address, account_pk);

  const wait = 20000;

  let response = await account.declareAndDeploy({
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
      starknet_commit_address: '0x8bF85537c80beCbA711447f66A9a4452e3575E29',
    }),
  });

  const ethTxAuthenticatorAddress = response.deploy.contract_address;
  console.log('ethTxAuthenticatorAddress: ', ethTxAuthenticatorAddress);
  delay(wait);

  response = await account.declareAndDeploy({
    contract: starkSigAuthenticatorSierra,
    casm: starkSigAuthenticatorCasm,
    constructorCalldata: CallData.compile({ name: 'sx-starknet', version: '0.1.0' }),
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
    contract: factorySierra,
    casm: factoryCasm,
    constructorCalldata: CallData.compile({}),
  });

  const factoryAddress = response.deploy.contract_address;
  console.log('factoryAddress: ', factoryAddress);

  //   const deployments = {
  //     vanillaAuthenticator: vanillaAuthenticatorAddress,
  //     ethSigAuthenticator: ethSigAuthenticatorAddress,
  //     ethTxAuthenticator: ethTxAuthenticatorAddress,
  //     starkSigAuthenticator: starkSigAuthenticatorAddress,
  //     starkTxAuthenticator: starkTxAuthenticatorAddress,
  //     ethRelayerExecutionStrategy: ethRelayerExecutionStrategyAddress,
  //     noExecutionSimpleMajorityExecutionStrategy: noExecutionSimpleMajorityExecutionStrategyAddress,
  //     vanillaProposalValidationStrategy: vanillaProposalValidationStrategyAddress,
  //     propositionPowerProposalValidationStrategy: propositionPowerProposalValidationStrategyAddress,
  //     erc20VotesVotingStrategy: erc20VotesVotingStrategyAddress,
  //     merkleWhitelistVotingStrategy: merkleWhitelistVotingStrategyAddress,
  //     factory: factoryAddress,
  //     space: spaceAddress,
  //   };

  //   fs.writeFileSync('./deployments/goerli.json', JSON.stringify(deployments));
}

main();
