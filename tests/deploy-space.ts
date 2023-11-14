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

  const l1TokenAddress = '0xd96844c9B21CB6cCf2c236257c7fc703E43BA071'; //OZ token 18 decimals
  const slotIndex = cairo.uint256(0);

  const factsRegistryAddress = '0x57e6ac564b898df3501f5c7d42801ad14d49c2889f29eaec0e0e552fb32ef7f';
  const timestampsRemapperAddress =
    '0x047b9a752a0a1fd25c311f6b85c4bafead66a3784b9ccc8d666300d91efca604';

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

  // const deployResponse = await account.declareAndDeploy({
  //   contract: evmSlotValueVotingStrategySierra,
  //   casm: evmSlotValueVotingStrategyCasm,
  //   constructorCalldata: CallData.compile({
  //     timestamp_remappers: timestampsRemapperAddress,
  //     facts_registry: factsRegistryAddress,
  //   }),
  // });
  const evmSlotValueVotingStrategyAddress = "0x01a46b1377e24153a0de0a22dc72a55c25cc3ead01b3c98f55eef2c3ad206de5" //deployResponse.deploy.contract_address;
  console.log('Voting Strategy Address: ', evmSlotValueVotingStrategyAddress);

  // const spaceDeployResponse = await account.declareAndDeploy({
  //   contract: spaceSierra,
  //   casm: spaceCasm,
  //   constructorCalldata: CallData.compile({}),
  // });
  const spaceAddress = "0x07ad2ef0b2100b37b62c5c132ceefd060c78170c761a56cd0a795ffc4f922fc1" //spaceDeployResponse.deploy.contract_address;
  console.log('Space Address: ', spaceAddress);

  // initialize space
  const result = await account.execute({
    contractAddress: spaceAddress,
    entrypoint: 'initialize',
    calldata: CallData.compile({
      _owner: 1,
      _max_voting_duration: 20000,
      _min_voting_duration: 20000,
      _voting_delay: 0,
      _proposal_validation_strategy: {
        address: vanillaProposalValidationStrategyAddress,
        params: [],
      },
      _proposal_validation_strategy_metadata_uri: [],
      _voting_strategies: [
        {
          address: evmSlotValueVotingStrategyAddress,
          params: [l1TokenAddress, slotIndex.low, slotIndex.high],
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
