import fs from 'fs';
import {
  defaultProvider,
  Provider,
  RpcProvider,
  Account,
  ec,
  json,
  CallData,
  constants,
  shortString,
  cairo,
} from 'starknet';

async function main() {
  const account_address = '0x0071399180e89305007c030004d68ebbed03e2b6d780de66ba36c64630acca52';
  const account_pk = '0x2587FB9D2FE799E759769D7DB115018C4FDF8F0F4047AE5E0A6C17B56B8B224';
  const network = 'https://starknet-goerli.g.alchemy.com/v2/2rHwIyOetFjUsdM4M_SBXpj1ejkck6lr';
  const provider = new RpcProvider({ nodeUrl: network });
  const account = new Account(provider, account_address, account_pk);

  const evmSlotValueVotingStrategySierra = json.parse(
    fs
      .readFileSync('starknet/target/dev/sx_EvmSlotValueVotingStrategy.sierra.json')
      .toString('ascii'),
  );
  const evmSlotValueVotingStrategyCasm = json.parse(
    fs
      .readFileSync('starknet/target/dev/sx_EvmSlotValueVotingStrategy.casm.json')
      .toString('ascii'),
  );
  const vanillaAuthenticatorSierra = json.parse(
    fs.readFileSync('starknet/target/dev/sx_VanillaAuthenticator.sierra.json').toString('ascii'),
  );
  const vanillaAuthenticatorCasm = json.parse(
    fs.readFileSync('starknet/target/dev/sx_VanillaAuthenticator.casm.json').toString('ascii'),
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

  const spaceSierra = json.parse(
    fs.readFileSync('starknet/target/dev/sx_Space.sierra.json').toString('ascii'),
  );
  const spaceCasm = json.parse(
    fs.readFileSync('starknet/target/dev/sx_Space.casm.json').toString('ascii'),
  );

  //   const vanillaAuthenticatorDeployResponse = await account.declareAndDeploy({
  //     contract: vanillaAuthenticatorSierra,
  //     casm: vanillaAuthenticatorCasm,
  //     constructorCalldata: CallData.compile({}),
  //   });
  const vanillaAuthenticatorAddress =
    '0x6fa12cffc11ba775ccf99bad7249f06ec5fc605d002716b2f5c7f5561d28081'; //vanillaAuthenticatorDeployResponse.deploy.contract_address;
  console.log('Vanilla Authenticator Address: ', vanillaAuthenticatorAddress);

  //   const vanillaProposalValidationStrategyDeployResponse = await account.declareAndDeploy({
  //     contract: vanillaProposalValidationStrategySierra,
  //     casm: vanillaProposalValidationStrategyCasm,
  //     constructorCalldata: CallData.compile({}),
  //   });
  const vanillaProposalValidationStrategyAddress =
    '0x18f74b960aeea1b8b8c14eb1834f37fd6e52daed66e983e7364d1f69dc7dbfb';
  // vanillaProposalValidationStrategyDeployResponse.deploy.contract_address;
  console.log(
    'Vanilla Proposal Validation Strategy Address: ',
    vanillaProposalValidationStrategyAddress,
  );

  //   const deployResponse = await account.declareAndDeploy({
  //     contract: evmSlotValueVotingStrategySierra,
  //     casm: evmSlotValueVotingStrategyCasm,
  //     constructorCalldata: CallData.compile({
  //       timestamp_remappers: '0x0231080ccb479ac0fd23a65c83e4be4bb8c93a4e69a6e51e892c529e2f870dfe',
  //       facts_registry: '0x031653659964bc969905e1b1c18deb69c65efb2e22ff7f4102044d432c91b82d',
  //     }),
  //   });
  const evmSlotValueVotingStrategyAddress =
    '0x78b96d9c0509e7dc93ae36d17d44b2c8b39453a43e4b563c367993c755fce97'; //deployResponse.deploy.contract_address;
  console.log('Voting Strategy Address: ', evmSlotValueVotingStrategyAddress);

//   const spaceDeployResponse = await account.declareAndDeploy({
//     contract: spaceSierra,
//     casm: spaceCasm,
//     constructorCalldata: CallData.compile({}),
//   });
  const spaceAddress = "0x038010123867fe31551fbaa813b54d68627034a897e9b1791b801d46de63f127"; //spaceDeployResponse.deploy.contract_address;
  console.log('Space Address: ', spaceAddress);

  // initialize space
  const result = await account.execute({
    contractAddress: spaceAddress,
    entrypoint: 'initialize',
    calldata: CallData.compile({
      _owner: 1,
      _max_voting_duration: 200,
      _min_voting_duration: 200,
      _voting_delay: 100,
      _proposal_validation_strategy: {
        address: vanillaProposalValidationStrategyAddress,
        params: [],
      },
      _proposal_validation_strategy_metadata_uri: [],
      _voting_strategies: [
        {
          address: evmSlotValueVotingStrategyAddress,
          params: ['0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984', '0x4'],
        },
      ],
      _voting_strategies_metadata_uri: [[]],
      _authenticators: [vanillaAuthenticatorAddress],
      _metadata_uri: [],
      _dao_uri: [],
    }),
  });
}

main();
