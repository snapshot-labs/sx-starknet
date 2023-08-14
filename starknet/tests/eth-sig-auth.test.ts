import fs from 'fs';
import { ethers } from 'ethers';
import dotenv from 'dotenv';
import { Provider, Account, CallData, cairo, json } from 'starknet';
import {
  Propose,
  proposeTypes,
  voteTypes,
  Vote,
  updateProposalTypes,
  UpdateProposal,
} from './types';

dotenv.config();

const network = process.env.NETWORK_URL || '';

describe('Ethereum Signature Authenticator', () => {
  const provider = new Provider({ sequencer: { baseUrl: network } });
  // starknet devnet predeployed account 0 with seed 0
  const privateKey0 = '0xe3e70682c2094cac629f6fbed82c07cd';
  const address0 = '0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a';
  const account0 = new Account(provider, address0, privateKey0);

  let signer: ethers.HDNodeWallet;
  let spaceAddress: string;
  let vanillaVotingStrategyAddress: string;
  let vanillaProposalValidationStrategyAddress: string;
  let ethSigAuthAddress: string;
  let domain: any;

  beforeAll(async () => {
    signer = ethers.Wallet.createRandom();
    // Deploy Ethereum Signature Authenticator
    const ethSigAuthSierra = json.parse(
      fs.readFileSync('starknet/target/dev/sx_EthSigAuthenticator.sierra.json').toString('ascii'),
    );
    const ethSigAuthCasm = json.parse(
      fs.readFileSync('starknet/target/dev/sx_EthSigAuthenticator.casm.json').toString('ascii'),
    );

    let deployResponse = await account0.declareAndDeploy({
      contract: ethSigAuthSierra,
      casm: ethSigAuthCasm,
      constructorCalldata: CallData.compile({}),
    });

    ethSigAuthAddress = deployResponse.deploy.contract_address;

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
        _voting_delay: 1,
        _proposal_validation_strategy: {
          address: vanillaProposalValidationStrategyAddress,
          params: [[]],
        },
        _proposal_validation_strategy_metadata_URI: [],
        _voting_strategies: [{ address: vanillaVotingStrategyAddress, params: [] }],
        _voting_strategies_metadata_URI: [],
        _authenticators: [ethSigAuthAddress],
        _metadata_URI: [],
        _dao_URI: [],
      }),
    });
    spaceAddress = deployResponse.deploy.contract_address;

    domain = {
      chainId: '0x534e5f474f45524c49', // devnet id
    };
  }, 1000000);
  test('can authenticate a proposal, a vote, and a proposal update', async () => {
    // PROPOSE

    const proposeMsg: Propose = {
      authenticator: ethSigAuthAddress,
      space: spaceAddress,
      author: signer.address,
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x0'],
      },
      userProposalValidationParams: [
        '0xffffffffffffffffffffffffffffffffffffffffff',
        '0x1234',
        '0x5678',
        '0x9abc',
      ],
      metadataURI: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x0',
    };

    let sig = await signer.signTypedData(domain, proposeTypes, proposeMsg);
    let splitSig = getRSVFromSig(sig);

    const proposeCalldata = {
      r: cairo.uint256(splitSig.r),
      s: cairo.uint256(splitSig.s),
      v: splitSig.v,
      space: proposeMsg.space,
      author: proposeMsg.author,
      executionStrategy: proposeMsg.executionStrategy,
      userProposalValidationParams: proposeMsg.userProposalValidationParams,
      metadataURI: proposeMsg.metadataURI,
      salt: cairo.uint256(proposeMsg.salt),
    };

    let result = await account0.execute({
      contractAddress: ethSigAuthAddress,
      entrypoint: 'authenticate_propose',
      calldata: CallData.compile(proposeCalldata as any),
    });

    console.log(result);

    // UPDATE PROPOSAL

    const updateProposalMsg: UpdateProposal = {
      authenticator: ethSigAuthAddress,
      space: spaceAddress,
      author: signer.address,
      proposalId: '0x1',
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x0'],
      },
      metadataURI: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x1',
    };

    sig = await signer.signTypedData(domain, updateProposalTypes, updateProposalMsg);
    splitSig = getRSVFromSig(sig);

    const updateProposalCalldata = {
      r: cairo.uint256(splitSig.r),
      s: cairo.uint256(splitSig.s),
      v: splitSig.v,
      space: updateProposalMsg.space,
      author: updateProposalMsg.author,
      proposalId: cairo.uint256(updateProposalMsg.proposalId),
      executionStrategy: updateProposalMsg.executionStrategy,
      metadataURI: updateProposalMsg.metadataURI,
      salt: cairo.uint256(updateProposalMsg.salt),
    };

    result = await account0.execute({
      contractAddress: ethSigAuthAddress,
      entrypoint: 'authenticate_update_proposal',
      calldata: CallData.compile(updateProposalCalldata as any),
    });

    console.log(result);

    {
      // Random Tx just to advance the block number on the devnet so the voting period begins.

      await account0.declareAndDeploy({
        contract: json.parse(
          fs
            .readFileSync('starknet/target/dev/sx_EthSigAuthenticator.sierra.json')
            .toString('ascii'),
        ),
        casm: json.parse(
          fs.readFileSync('starknet/target/dev/sx_EthSigAuthenticator.casm.json').toString('ascii'),
        ),
        constructorCalldata: CallData.compile({}),
      });
    }

    // VOTE

    const voteMsg: Vote = {
      authenticator: ethSigAuthAddress,
      space: spaceAddress,
      voter: signer.address,
      proposalId: '0x1',
      choice: '0x1',
      userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }],
      metadataURI: ['0x1', '0x2', '0x3', '0x4'],
    };

    sig = await signer.signTypedData(domain, voteTypes, voteMsg);
    splitSig = getRSVFromSig(sig);

    const voteCalldata = {
      r: cairo.uint256(splitSig.r),
      s: cairo.uint256(splitSig.s),
      v: splitSig.v,
      space: voteMsg.space,
      voter: voteMsg.voter,
      proposalId: cairo.uint256(voteMsg.proposalId),
      choice: voteMsg.choice,
      userVotingStrategies: voteMsg.userVotingStrategies,
      metadataURI: voteMsg.metadataURI,
    };

    result = await account0.execute({
      contractAddress: ethSigAuthAddress,
      entrypoint: 'authenticate_vote',
      calldata: CallData.compile(voteCalldata as any),
    });

    console.log(result);
  }, 1000000);
});

// From sx.js
function getRSVFromSig(sig: string) {
  if (sig.startsWith('0x')) {
    sig = sig.substring(2);
  }
  const r = `0x${sig.substring(0, 64)}`;
  const s = `0x${sig.substring(64, 64 * 2)}`;
  const v = `0x${sig.substring(64 * 2)}`;
  return { r, s, v };
}
