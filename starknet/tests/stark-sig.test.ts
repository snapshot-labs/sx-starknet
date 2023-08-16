import fs from 'fs';
import dotenv from 'dotenv';
import { Provider, Account, CallData, typedData, shortString, json } from 'starknet';
import {
  proposeTypes,
  voteTypes,
  updateProposalTypes,
  Propose,
  Vote,
  UpdateProposal,
  StarknetSigProposeCalldata,
  StarknetSigVoteCalldata,
  StarknetSigUpdateProposalCalldata,
} from './types';

dotenv.config();

const network = process.env.NETWORK_URL || '';

describe('Starknet Signature Authenticator', () => {
  const provider = new Provider({ sequencer: { baseUrl: network } });
  // starknet devnet predeployed account 0 with seed 0
  const privateKey_0 = '0xe3e70682c2094cac629f6fbed82c07cd';
  const address0 = '0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a';
  const account0 = new Account(provider, address0, privateKey_0);

  // change this to 'camel' if the account interface uses camel case
  const account0Type = shortString.encodeShortString('snake');

  let spaceAddress: string;
  let vanillaVotingStrategyAddress: string;
  let vanillaProposalValidationStrategyAddress: string;
  let starkSigAuthAddress: string;
  let domain: any;

  beforeAll(async () => {
    // Deploy Starknet Signature Authenticator
    const starkSigAuthSierra = json.parse(
      fs.readFileSync('starknet/target/dev/sx_StarkSigAuthenticator.sierra.json').toString('ascii'),
    );
    const starkSigAuthCasm = json.parse(
      fs.readFileSync('starknet/target/dev/sx_StarkSigAuthenticator.casm.json').toString('ascii'),
    );

    let deployResponse = await account0.declareAndDeploy({
      contract: starkSigAuthSierra,
      casm: starkSigAuthCasm,
      constructorCalldata: CallData.compile({ name: 'sx-sn', version: '0.1.0' }),
    });
    starkSigAuthAddress = deployResponse.deploy.contract_address;

    // Deploy Vanilla Voting Strategy
    const vanillaVotingStrategySierra = json.parse(
      fs.readFileSync('starknet/target/dev/sx_VanillaVotingStrategy.sierra.json').toString('ascii'),
    );
    const vanillaVotingStrategyCasm = json.parse(
      fs.readFileSync('starknet/target/dev/sx_VanillaVotingStrategy.casm.json').toString('ascii'),
    );

    deployResponse = await account0.declareAndDeploy({
      contract: vanillaVotingStrategySierra,
      casm: vanillaVotingStrategyCasm,
      constructorCalldata: CallData.compile({}),
    });
    vanillaVotingStrategyAddress = deployResponse.deploy.contract_address;

    // Deploy Vanilla Proposal Validation Strategy
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

    deployResponse = await account0.declareAndDeploy({
      contract: vanillaProposalValidationStrategySierra,
      casm: vanillaProposalValidationStrategyCasm,
      constructorCalldata: CallData.compile({}),
    });
    vanillaProposalValidationStrategyAddress = deployResponse.deploy.contract_address;

    // Deploy Space
    const spaceSierra = json.parse(
      fs.readFileSync('starknet/target/dev/sx_Space.sierra.json').toString('ascii'),
    );
    const spaceCasm = json.parse(
      fs.readFileSync('starknet/target/dev/sx_Space.casm.json').toString('ascii'),
    );

    deployResponse = await account0.declareAndDeploy({
      contract: spaceSierra,
      casm: spaceCasm,
      constructorCalldata: CallData.compile({
        _owner: 1,
        _max_voting_duration: 100,
        _min_voting_duration: 100,
        _voting_delay: 10,
        _proposal_validation_strategy: {
          address: vanillaProposalValidationStrategyAddress,
          params: [[]],
        },
        _proposal_validation_strategy_metadata_URI: [],
        _voting_strategies: [{ address: vanillaVotingStrategyAddress, params: [] }],
        _voting_strategies_metadata_URI: [],
        _authenticators: [starkSigAuthAddress],
        _metadata_URI: [],
        _dao_URI: [],
      }),
    });
    spaceAddress = deployResponse.deploy.contract_address;

    domain = {
      name: 'sx-sn',
      version: '0.1.0',
      chainId: '0x534e5f474f45524c49', // devnet id
      verifyingContract: starkSigAuthAddress,
    };
  }, 100000);
  test('can authenticate a proposal, a vote, and a proposal update', async () => {
    // PROPOSE
    const proposeMsg: Propose = {
      space: spaceAddress,
      author: address0,
      executionStrategy: {
        address: '0x0000000000000000000000000000000000001234',
        params: ['0x5', '0x6', '0x7', '0x8'],
      },
      userProposalValidationParams: ['0x1', '0x2', '0x3', '0x4'],
      metadataURI: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x0',
    };

    const proposeData: typedData.TypedData = {
      types: proposeTypes,
      primaryType: 'Propose',
      domain: domain,
      message: proposeMsg as any,
    };

    const proposeSig = (await account0.signMessage(proposeData)) as any;

    const proposeCalldata: StarknetSigProposeCalldata = {
      signature: [proposeSig.r, proposeSig.s],
      ...proposeMsg,
      accountType: account0Type,
    };

    await account0.execute({
      contractAddress: starkSigAuthAddress,
      entrypoint: 'authenticate_propose',
      calldata: CallData.compile(proposeCalldata as any),
    });

    // UPDATE PROPOSAL

    const updateProposalMsg: UpdateProposal = {
      space: spaceAddress,
      author: address0,
      proposalId: { low: '0x1', high: '0x0' },
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x5', '0x6', '0x7', '0x8'],
      },
      metadataURI: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x1',
    };
    const updateProposalData: typedData.TypedData = {
      types: updateProposalTypes,
      primaryType: 'UpdateProposal',
      domain: domain,
      message: updateProposalMsg as any,
    };

    const updateProposalSig = (await account0.signMessage(updateProposalData)) as any;

    const updateProposalCalldata: StarknetSigUpdateProposalCalldata = {
      signature: [updateProposalSig.r, updateProposalSig.s],
      ...updateProposalMsg,
      accountType: account0Type,
    };

    await account0.execute({
      contractAddress: starkSigAuthAddress,
      entrypoint: 'authenticate_update_proposal',
      calldata: CallData.compile(updateProposalCalldata as any),
    });

    // VOTE

    const voteMsg: Vote = {
      space: spaceAddress,
      voter: address0,
      proposalId: { low: '0x1', high: '0x0' },
      choice: '0x1',
      userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }],
      metadataURI: ['0x1', '0x2', '0x3', '0x4'],
    };

    const voteData: typedData.TypedData = {
      types: voteTypes,
      primaryType: 'Vote',
      domain: domain,
      message: voteMsg as any,
    };

    const voteSig = (await account0.signMessage(voteData)) as any;

    const voteCalldata: StarknetSigVoteCalldata = {
      signature: [voteSig.r, voteSig.s],
      ...voteMsg,
      accountType: account0Type,
    };

    await account0.execute({
      contractAddress: starkSigAuthAddress,
      entrypoint: 'authenticate_vote',
      calldata: CallData.compile(voteCalldata as any),
    });
  }, 1000000);
});
