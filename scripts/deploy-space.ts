import dotenv from 'dotenv';
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

dotenv.config();

const accountAddress = process.env.ADDRESS || '';
const accountPk = process.env.PK || '';
const starknetNetworkUrl = process.env.STARKNET_NETWORK_URL || '';

// 1 or 11155111
const l1ChainId = process.env.L1_CHAIN_ID || '';

// TODO: refactor deployment scripts
async function main() {
  const provider = new RpcProvider({ nodeUrl: starknetNetworkUrl });
  const account = new Account(provider, accountAddress, accountPk);

  // OZ Votes token 18 decimals
  const l1TokenAddress = '0xd96844c9B21CB6cCf2c236257c7fc703E43BA071';

  // Slot index of the checkpoints mapping in the token contract,
  // obtained using Foundry's Cast Storage Layout tool.
  const slotIndex = cairo.uint256(8);

  // Herodotus Satellite contract deployed on Starknet mainnet
  const satelliteContractAddress =
    '0x01ba7d4b5707f8878c22fb335763abfc26c2ae157c434d597f6416fe6a79bf2e';

  const evmSlotValueVotingStrategySierra = json.parse(
    fs
      .readFileSync('starknet/target/dev/sx_OZVotesStorageProofVotingStrategy.sierra.json')
      .toString('ascii'),
  );
  const evmSlotValueVotingStrategyCasm = json.parse(
    fs
      .readFileSync('starknet/target/dev/sx_OZVotesStorageProofVotingStrategy.casm.json')
      .toString('ascii'),
  );
  const spaceSierra = json.parse(
    fs.readFileSync('starknet/target/dev/sx_Space.sierra.json').toString('ascii'),
  );
  const spaceCasm = json.parse(
    fs.readFileSync('starknet/target/dev/sx_Space.casm.json').toString('ascii'),
  );

  const vanillaAuthenticatorAddress =
    '0x046ad946f22ac4e14e271f24309f14ac36f0fde92c6831a605813fefa46e0893';

  const vanillaProposalValidationStrategyAddress =
    '0x2247f5d86a60833da9dd8224d8f35c60bde7f4ca3b2a6583d4918d48750f69';

  // const deployResponse = await account.declareAndDeploy({
  //   contract: evmSlotValueVotingStrategySierra,
  //   casm: evmSlotValueVotingStrategyCasm,
  //   constructorCalldata: CallData.compile({
  //     satellite_contract: satelliteContractAddress,
  //     chain_id: l1ChainId,
  //   }),
  // });
  // const evmSlotValueVotingStrategyAddress = deployResponse.deploy.contract_address;

  const evmSlotValueVotingStrategyAddress =
    '0x474edaba6e88a1478d0680bb97f43f01e6a311593ddc496da58d5a7e7a647cf';
  console.log('Voting Strategy Address: ', evmSlotValueVotingStrategyAddress);

  const spaceDeployResponse = await account.declareAndDeploy({
    contract: spaceSierra,
    casm: spaceCasm,
    constructorCalldata: CallData.compile({}),
  });
  const spaceAddress = spaceDeployResponse.deploy.contract_address;
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
