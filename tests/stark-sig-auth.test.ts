import { expect } from 'chai';
import dotenv from 'dotenv';
import { CallData, typedData, shortString, Account, RpcProvider, Contract, StarknetDomain } from 'starknet';
import { Devnet } from 'starknet-devnet';
import {
  proposeTypes,
  voteTypes,
  updateProposalTypes,
  Propose,
  Vote,
  UpdateProposal,
} from './stark-sig-types';
import { getCompiledCode } from './utils';
import { TypedData as StarknetTypedData } from 'starknet';
import { TypedDataRevision as Revision } from 'starknet';
import { CairoCustomEnum } from 'starknet';


dotenv.config();

const account_address = process.env.ADDRESS || '';
const account_public_key = process.env.PUBLIC_KEY || '';
const account_pk = process.env.PK || '';

describe('Starknet Signature Authenticator Tests', function () {
  this.timeout(1000000);
  let account: Account;

  let starkSigAuthenticator: Contract;
  let vanillaVotingStrategy: Contract;
  let vanillaProposalValidationStrategy: Contract;
  let space: Contract;
  let devnet: Devnet;
  let provider: RpcProvider

  let domain: any;

  before(async function () {
    console.log('account address:', account_address, 'account pk:', account_pk);

    const devnetConfig = {
      args: ["--seed", "42", "--lite-mode"]
    };
    devnet = await Devnet.spawnInstalled(devnetConfig); // TODO
    console.log(await devnet.provider.isAlive()); // true

    provider = new RpcProvider({ nodeUrl: devnet.provider.url });

    // Account used for deployments
    account = new Account(provider, account_address, account_pk);

    const domain_name = 'sx-sn';
    const domain_version = '0.1.0';

    // Deploy the Stark Sig Authenticator
    const { sierraCode: sig_sierra, casmCode: sig_casm } = await getCompiledCode('sx_StarkSigAuthenticator');
    const sig_calldata = CallData.compile({ name: domain_name, version: domain_version });
    const sig_response = await account.declareAndDeploy({
      contract: sig_sierra,
      casm: sig_casm,
      constructorCalldata: sig_calldata,
    });
    starkSigAuthenticator = new Contract(sig_sierra.abi, sig_response.deploy.contract_address, provider);
    console.log("Stark Sig Authenticator: ", starkSigAuthenticator.address);

    // Deploy the Vanilla Voting strategy
    const { sierraCode: voting_sierra, casmCode: voting_casm } = await getCompiledCode('sx_VanillaVotingStrategy');
    const voting_response = await account.declareAndDeploy({ contract: voting_sierra, casm: voting_casm });
    vanillaVotingStrategy = new Contract(voting_sierra.abi, voting_response.deploy.contract_address, provider);
    console.log("Vanilla Voting Strategy: ", vanillaVotingStrategy.address);

    // Deploy the Vanilla Proposal Validation strategy
    const { sierraCode: proposal_sierra, casmCode: proposal_casm } = await getCompiledCode('sx_VanillaProposalValidationStrategy');
    const proposal_response = await account.declareAndDeploy({ contract: proposal_sierra, casm: proposal_casm });
    vanillaProposalValidationStrategy = new Contract(proposal_sierra.abi, proposal_response.deploy.contract_address, provider);
    console.log("Vanilla Proposal Validation Strategy: ", vanillaProposalValidationStrategy.address);

    // Deploy the Space
    const { sierraCode: space_sierra, casmCode: space_casm } = await getCompiledCode('sx_Space');
    const space_response = await account.declareAndDeploy({ contract: space_sierra, casm: space_casm });
    space = new Contract(space_sierra.abi, space_response.deploy.contract_address, provider);
    console.log("Space: ", space.address);

    // Connect with our account
    space.connect(account);

    const _owner = 1;
    const _max_voting_duration = 200;
    const _min_voting_duration = 200;
    const _voting_delay = 100;
    const _proposal_validation_strategy = {
      address: vanillaProposalValidationStrategy.address,
      params: [],
    };
    const _proposal_validation_strategy_metadata_uri = [];
    const _voting_strategies = [{ address: vanillaVotingStrategy.address, params: [] }];
    const _voting_strategies_metadata_uri = [[]];
    const _authenticators = [starkSigAuthenticator.address];
    const _metadata_uri = [];
    const _dao_uri = [];

    console.log("Initializing space...");
    const initializeRes = await space.initialize(
      _owner,
      _max_voting_duration,
      _min_voting_duration,
      _voting_delay,
      _proposal_validation_strategy,
      _proposal_validation_strategy_metadata_uri,
      _voting_strategies,
      _voting_strategies_metadata_uri,
      _authenticators,
      _metadata_uri,
      _dao_uri);
    await provider.waitForTransaction(initializeRes.transaction_hash);

    domain = {
      name: domain_name,
      version: domain_version,
      chainId: '0x534e5f5345504f4c4941', // 'SN_SEPOLIA'
    };

    // TODO: Dumping the Starknet state so it can be loaded at the same point for each test
    // await starknet.devnet.dump('dump.pkl');
  });

  it('can authenticate a proposal, a vote, and a proposal update', async () => {
    // await starknet.devnet.restart();
    // await starknet.devnet.load('./dump.pkl');
    // await starknet.devnet.increaseTime(10);

    // PROPOSE
    const proposeMsg: Propose = {
      space: space.address,
      author: account.address,
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
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
      salt: '0x0',
    };

    console.log("Signing proposal message...");
    const proposeSig = (await account.signMessage({
      types: proposeTypes,
      primaryType: 'Propose',
      domain: domain as StarknetDomain,
      message: proposeMsg as any,
    } as StarknetTypedData)) as any;

    const d = {
      types: proposeTypes,
      primaryType: 'Propose',
      domain: domain,
      message: proposeMsg as any,
    } as StarknetTypedData;

    starkSigAuthenticator.connect(account);

    console.log("Authenticating proposal...");
    const proposeSignature = [proposeSig.r, proposeSig.s];
    const proposeRes = await starkSigAuthenticator.authenticate_propose(proposeSignature, proposeMsg.space, proposeMsg.author, proposeMsg.metadataUri, proposeMsg.executionStrategy, proposeMsg.userProposalValidationParams, proposeMsg.salt);
    await provider.waitForTransaction(proposeRes.transaction_hash);

    // UPDATE PROPOSAL

    const updateProposalMsg: UpdateProposal = {
      space: space.address,
      author: account.address,
      proposalId: { low: '0x1', high: '0x0' },
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x5', '0x6', '0x7', '0x8'],
      },
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x1',
    };

    const updateProposalSig = (await account.signMessage({
      types: updateProposalTypes,
      primaryType: 'UpdateProposal',
      domain: domain,
      message: updateProposalMsg as any,
    } as StarknetTypedData)) as any;

    console.log("Updating proposal...");
    const updateSignature = [updateProposalSig.r, updateProposalSig.s];
    const updateRes = await starkSigAuthenticator.authenticate_update_proposal(updateSignature, updateProposalMsg.space, updateProposalMsg.author, updateProposalMsg.proposalId, updateProposalMsg.executionStrategy, updateProposalMsg.metadataUri, updateProposalMsg.salt);
    await provider.waitForTransaction(updateRes.transaction_hash);

    // Increase time so voting period begins TODO
    devnet.provider.increaseTime(100);

    // VOTE
    const voteMsg: Vote = {
      space: space.address,
      voter: account.address,
      proposalId: { low: '0x1', high: '0x0' },
      choice: '0x1',
      userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }],
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
    };

    const voteSig = (await account.signMessage({
      types: voteTypes,
      primaryType: 'Vote',
      domain: domain,
      message: voteMsg as any,
    } as StarknetTypedData)) as any;

    console.log("Voting...");
    const voteSignature = [voteSig.r, voteSig.s];
    const choice = new CairoCustomEnum({ For: {} });
    const voteRes = await starkSigAuthenticator.authenticate_vote(voteSignature, voteMsg.space, voteMsg.voter, voteMsg.proposalId, choice, voteMsg.userVotingStrategies, voteMsg.metadataUri);
    await provider.waitForTransaction(voteRes.transaction_hash);
  });

  // it('should revert if an incorrect signature is used', async () => {
  //   await starknet.devnet.restart();
  //   await starknet.devnet.load('./dump.pkl');
  //   await starknet.devnet.increaseTime(10);

  //   // Account #1 on Starknet devnet with seed 42
  //   const invalidAccountWithSigner = new Account(
  //     new Provider({ sequencer: { baseUrl: network } }),
  //     '0x7aac39162d91acf2c4f0d539f4b81e23832619ac0c3df9fce22e4a8d505632a',
  //     '0x23b8c1e9392456de3eb13b9046685257',
  //   );

  //   // PROPOSE
  //   const proposeMsg: Propose = {
  //     space: space.address,
  //     author: accountWithSigner.address,
  //     metadataUri: ['0x1', '0x2', '0x3', '0x4'],
  //     executionStrategy: {
  //       address: '0x0000000000000000000000000000000000005678',
  //       params: ['0x0'],
  //     },
  //     userProposalValidationParams: [
  //       '0xffffffffffffffffffffffffffffffffffffffffff',
  //       '0x1234',
  //       '0x5678',
  //       '0x9abc',
  //     ],
  //     salt: '0x0',
  //   };

  //   const invalidProposeSig = (await invalidAccountWithSigner.signMessage({
  //     types: proposeTypes,
  //     primaryType: 'Propose',
  //     domain: domain,
  //     message: proposeMsg as any,
  //   } as typedData.TypedData)) as any;

  //   const invalidProposeCalldata = CallData.compile({
  //     signature: [invalidProposeSig.r, invalidProposeSig.s],
  //     ...proposeMsg,
  //   });

  //   try {
  //     await account.invoke(starkSigAuthenticator, 'authenticate_propose', invalidProposeCalldata, {
  //       rawInput: true,
  //     });
  //     expect.fail('Should have failed');
  //   } catch (err: any) {
  //     expect(err.message).to.contain(shortString.encodeShortString('Invalid Signature'));
  //   }

  //   const proposeSig = (await accountWithSigner.signMessage({
  //     types: proposeTypes,
  //     primaryType: 'Propose',
  //     domain: domain,
  //     message: proposeMsg as any,
  //   } as typedData.TypedData)) as any;

  //   const proposeCalldata = CallData.compile({
  //     signature: [proposeSig.r, proposeSig.s],
  //     ...proposeMsg,
  //   });

  //   await account.invoke(starkSigAuthenticator, 'authenticate_propose', proposeCalldata, {
  //     rawInput: true,
  //   });

  //   // UPDATE PROPOSAL

  //   const updateProposalMsg: UpdateProposal = {
  //     space: space.address,
  //     author: accountWithSigner.address,
  //     proposalId: { low: '0x1', high: '0x0' },
  //     executionStrategy: {
  //       address: '0x0000000000000000000000000000000000005678',
  //       params: ['0x5', '0x6', '0x7', '0x8'],
  //     },
  //     metadataUri: ['0x1', '0x2', '0x3', '0x4'],
  //     salt: '0x1',
  //   };

  //   const invalidUpdateProposalSig = (await invalidAccountWithSigner.signMessage({
  //     types: updateProposalTypes,
  //     primaryType: 'UpdateProposal',
  //     domain: domain,
  //     message: updateProposalMsg as any,
  //   } as typedData.TypedData)) as any;

  //   const invalidUpdateProposalCalldata = CallData.compile({
  //     signature: [invalidUpdateProposalSig.r, invalidUpdateProposalSig.s],
  //     ...updateProposalMsg,
  //   });

  //   try {
  //     await account.invoke(
  //       starkSigAuthenticator,
  //       'authenticate_update_proposal',
  //       invalidUpdateProposalCalldata,
  //       {
  //         rawInput: true,
  //       },
  //     );
  //     expect.fail('Should have failed');
  //   } catch (err: any) {
  //     expect(err.message).to.contain(shortString.encodeShortString('Invalid Signature'));
  //   }

  //   const updateProposalSig = (await accountWithSigner.signMessage({
  //     types: updateProposalTypes,
  //     primaryType: 'UpdateProposal',
  //     domain: domain,
  //     message: updateProposalMsg as any,
  //   } as typedData.TypedData)) as any;

  //   const updateProposalCalldata = CallData.compile({
  //     signature: [updateProposalSig.r, updateProposalSig.s],
  //     ...updateProposalMsg,
  //   });

  //   await account.invoke(
  //     starkSigAuthenticator,
  //     'authenticate_update_proposal',
  //     updateProposalCalldata,
  //     {
  //       rawInput: true,
  //     },
  //   );

  //   // Increase time so voting period begins
  //   await starknet.devnet.increaseTime(100);

  //   // VOTE

  //   const voteMsg: Vote = {
  //     space: space.address,
  //     voter: accountWithSigner.address,
  //     proposalId: { low: '0x1', high: '0x0' },
  //     choice: '0x1',
  //     userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }],
  //     metadataUri: ['0x1', '0x2', '0x3', '0x4'],
  //   };

  //   const invalidVoteSig = (await invalidAccountWithSigner.signMessage({
  //     types: voteTypes,
  //     primaryType: 'Vote',
  //     domain: domain,
  //     message: voteMsg as any,
  //   } as typedData.TypedData)) as any;

  //   const invalidVoteCalldata = CallData.compile({
  //     signature: [invalidVoteSig.r, invalidVoteSig.s],
  //     ...voteMsg,
  //   });

  //   try {
  //     await account.invoke(starkSigAuthenticator, 'authenticate_vote', invalidVoteCalldata, {
  //       rawInput: true,
  //     });
  //     expect.fail('Should have failed');
  //   } catch (err: any) {
  //     expect(err.message).to.contain(shortString.encodeShortString('Invalid Signature'));
  //   }

  //   const voteSig = (await accountWithSigner.signMessage({
  //     types: voteTypes,
  //     primaryType: 'Vote',
  //     domain: domain,
  //     message: voteMsg as any,
  //   } as typedData.TypedData)) as any;

  //   const voteCalldata = CallData.compile({
  //     signature: [voteSig.r, voteSig.s],
  //     ...voteMsg,
  //   });

  //   await account.invoke(starkSigAuthenticator, 'authenticate_vote', voteCalldata, {
  //     rawInput: true,
  //   });
  // }, 1000000);

  // it('should revert if a salt is reused by an author when creating or updating a proposal', async () => {
  //   await starknet.devnet.restart();
  //   await starknet.devnet.load('./dump.pkl');
  //   await starknet.devnet.increaseTime(10);

  //   // PROPOSE
  //   const proposeMsg: Propose = {
  //     space: space.address,
  //     author: accountWithSigner.address,
  //     metadataUri: ['0x1', '0x2', '0x3', '0x4'],
  //     executionStrategy: {
  //       address: '0x0000000000000000000000000000000000005678',
  //       params: ['0x0'],
  //     },
  //     userProposalValidationParams: [
  //       '0xffffffffffffffffffffffffffffffffffffffffff',
  //       '0x1234',
  //       '0x5678',
  //       '0x9abc',
  //     ],
  //     salt: '0x0',
  //   };

  //   const proposeSig = (await accountWithSigner.signMessage({
  //     types: proposeTypes,
  //     primaryType: 'Propose',
  //     domain: domain,
  //     message: proposeMsg as any,
  //   } as typedData.TypedData)) as any;

  //   const proposeCalldata = CallData.compile({
  //     signature: [proposeSig.r, proposeSig.s],
  //     ...proposeMsg,
  //   });

  //   await account.invoke(starkSigAuthenticator, 'authenticate_propose', proposeCalldata, {
  //     rawInput: true,
  //   });

  //   try {
  //     await account.invoke(starkSigAuthenticator, 'authenticate_propose', proposeCalldata, {
  //       rawInput: true,
  //     });
  //     expect.fail('Should have failed');
  //   } catch (err: any) {
  //     expect(err.message).to.contain(shortString.encodeShortString('Salt Already Used'));
  //   }

  //   // UPDATE PROPOSAL

  //   const updateProposalMsg: UpdateProposal = {
  //     space: space.address,
  //     author: accountWithSigner.address,
  //     proposalId: { low: '0x1', high: '0x0' },
  //     executionStrategy: {
  //       address: '0x0000000000000000000000000000000000005678',
  //       params: ['0x5', '0x6', '0x7', '0x8'],
  //     },
  //     metadataUri: ['0x1', '0x2', '0x3', '0x4'],
  //     salt: '0x1',
  //   };

  //   const updateProposalSig = (await accountWithSigner.signMessage({
  //     types: updateProposalTypes,
  //     primaryType: 'UpdateProposal',
  //     domain: domain,
  //     message: updateProposalMsg as any,
  //   } as typedData.TypedData)) as any;

  //   const updateProposalCalldata = CallData.compile({
  //     signature: [updateProposalSig.r, updateProposalSig.s],
  //     ...updateProposalMsg,
  //   });

  //   await account.invoke(
  //     starkSigAuthenticator,
  //     'authenticate_update_proposal',
  //     updateProposalCalldata,
  //     {
  //       rawInput: true,
  //     },
  //   );

  //   try {
  //     await account.invoke(
  //       starkSigAuthenticator,
  //       'authenticate_update_proposal',
  //       updateProposalCalldata,
  //       {
  //         rawInput: true,
  //       },
  //     );
  //     expect.fail('Should have failed');
  //   } catch (err: any) {
  //     expect(err.message).to.contain(shortString.encodeShortString('Salt Already Used'));
  //   }
  // }, 1000000);
});
