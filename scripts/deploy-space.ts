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

const accountAddress = process.env.ADDRESS || '';
const accountPk = process.env.PK || '';
const starknetNetworkUrl = process.env.STARKNET_NETWORK_URL || '';

async function main() {
  const provider = new RpcProvider({ nodeUrl: starknetNetworkUrl });
  const account = new Account(provider, accountAddress, accountPk);

  const l1TokenAddress = '0xd96844c9B21CB6cCf2c236257c7fc703E43BA071'; //OZ token 18 decimals
  const slotIndex = cairo.uint256(0);

  const factsRegistryAddress = '0x01b2111317EB693c3EE46633edd45A4876db14A3a53ACDBf4E5166976d8e869d';
  const timestampsRemapperAddress =
    '0x2ee57d848297bc7dfc8675111b9aa3bd3085e4038e475250770afe303b772af';

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
  // const evmSlotValueVotingStrategyAddress =
  //   '0x07e95f740a049896784969d61389f119291a2de37186f7cfa8ba9d2f3037b32a'; //deployResponse.deploy.contract_address;

  const evmSlotValueVotingStrategyAddress =
    '0x06cf32ad42d1c6ee98758b00c6a7c7f293d9efb30f2afea370019a88f8e252be';
  console.log('Voting Strategy Address: ', evmSlotValueVotingStrategyAddress);

  // const spaceDeployResponse = await account.declareAndDeploy({
  //   contract: spaceSierra,
  //   casm: spaceCasm,
  //   constructorCalldata: CallData.compile({}),
  // });
  // const spaceAddress = '0x02b9ac7cb47a57ca4144fd0da74203bc8c4aaf411f438b08770bac3680a066cb'; //spaceDeployResponse.deploy.contract_address;
  // console.log('Space Address: ', spaceAddress);

  const spaceAddress = '0x040e53631973b92651746b4905655b0d797323fd2f47eb80cf6fad521a5ac87d';

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
