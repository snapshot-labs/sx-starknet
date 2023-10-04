import { expect } from 'chai';
import dotenv from 'dotenv';
import { starknet } from 'hardhat';
import { CallData, typedData, shortString, Account, Provider } from 'starknet';
import {
  proposeTypes,
  voteTypes,
  updateProposalTypes,
  Propose,
  Vote,
  UpdateProposal,
} from './stark-sig-types';

dotenv.config();

const account_address = process.env.ADDRESS || '';
const account_public_key = process.env.PUBLIC_KEY || '';
const account_pk = process.env.PK || '';
const network = process.env.STARKNET_NETWORK_URL || '';

describe('Starknet Signature Authenticator', function () {
  this.timeout(1000000);

  let account: starknet.starknetAccount;

  // SNIP-6 compliant account (the defaults deployed on the devnet are not SNIP-6 compliant and therefore cannot be used for s)
  let accountWithSigner: Account;

  let starkSigAuthenticator: starknet.StarknetContract;
  let vanillaVotingStrategy: starknet.StarknetContract;
  let vanillaProposalValidationStrategy: starknet.StarknetContract;
  let space: starknet.StarknetContract;

  let domain: any;

  before(async function () {
    account = await starknet.OpenZeppelinAccount.getAccountFromAddress(account_address, account_pk);
    const accountFactory = await starknet.getContractFactory('sx_Account');
    const starkSigAuthenticatorFactory = await starknet.getContractFactory(
      'sx_StarkSigAuthenticator',
    );
    const vanillaVotingStrategyFactory = await starknet.getContractFactory(
      'sx_VanillaVotingStrategy',
    );
    const vanillaProposalValidationStrategyFactory = await starknet.getContractFactory(
      'sx_VanillaProposalValidationStrategy',
    );
    const spaceFactory = await starknet.getContractFactory('sx_Space');

    try {
      // If the contracts are already declared, this will be skipped
      await account.declare(accountFactory);
      await account.declare(starkSigAuthenticatorFactory);
      await account.declare(vanillaVotingStrategyFactory);
      await account.declare(vanillaProposalValidationStrategyFactory);
      await account.declare(spaceFactory);
    } catch {}

    const accountObj = await account.deploy(accountFactory, {
      _public_key: account_public_key,
    });

    accountWithSigner = new Account(
      new Provider({ sequencer: { baseUrl: network } }),
      accountObj.address,
      account_pk,
    );

    starkSigAuthenticator = await account.deploy(starkSigAuthenticatorFactory, {
      name: shortString.encodeShortString('sx-sn'),
      version: shortString.encodeShortString('0.1.0'),
    });
    vanillaVotingStrategy = await account.deploy(vanillaVotingStrategyFactory);
    vanillaProposalValidationStrategy = await account.deploy(
      vanillaProposalValidationStrategyFactory,
    );
    space = await account.deploy(spaceFactory);

    // Initializing the space
    const initializeCalldata = CallData.compile({
      _owner: 1,
      _max_voting_duration: 200,
      _min_voting_duration: 200,
      _voting_delay: 100,
      _proposal_validation_strategy: {
        address: vanillaProposalValidationStrategy.address,
        params: [],
      },
      _proposal_validation_strategy_metadata_uri: [],
      _voting_strategies: [{ address: vanillaVotingStrategy.address, params: [] }],
      _voting_strategies_metadata_uri: [[]],
      _authenticators: [starkSigAuthenticator.address],
      _metadata_uri: [],
      _dao_uri: [],
    });

    await account.invoke(space, 'initialize', initializeCalldata, { rawInput: true });

    domain = {
      name: 'sx-sn',
      version: '0.1.0',
      chainId: '0x534e5f474f45524c49', // devnet id
      verifyingContract: starkSigAuthenticator.address,
    };

    // Dumping the Starknet state so it can be loaded at the same point for each test
    await starknet.devnet.dump('dump.pkl');
  }, 10000000);

  it('can authenticate a proposal, a vote, and a proposal update', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);

    // PROPOSE
    const proposeMsg: Propose = {
      space: space.address,
      author: accountWithSigner.address,
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

    const proposeSig = (await accountWithSigner.signMessage({
      types: proposeTypes,
      primaryType: 'Propose',
      domain: domain,
      message: proposeMsg as any,
    } as typedData.TypedData)) as any;

    const proposeCalldata = CallData.compile({
      signature: [proposeSig.r, proposeSig.s],
      ...proposeMsg,
    });

    await account.invoke(starkSigAuthenticator, 'authenticate_propose', proposeCalldata, {
      rawInput: true,
    });

    // UPDATE PROPOSAL

    const updateProposalMsg: UpdateProposal = {
      space: space.address,
      author: accountWithSigner.address,
      proposalId: { low: '0x1', high: '0x0' },
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x5', '0x6', '0x7', '0x8'],
      },
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x1',
    };

    const updateProposalSig = (await accountWithSigner.signMessage({
      types: updateProposalTypes,
      primaryType: 'UpdateProposal',
      domain: domain,
      message: updateProposalMsg as any,
    } as typedData.TypedData)) as any;

    const updateProposalCalldata = CallData.compile({
      signature: [updateProposalSig.r, updateProposalSig.s],
      ...updateProposalMsg,
    });

    await account.invoke(
      starkSigAuthenticator,
      'authenticate_update_proposal',
      updateProposalCalldata,
      {
        rawInput: true,
      },
    );

    // Increase time so voting period begins
    await starknet.devnet.increaseTime(100);

    // VOTE

    const voteMsg: Vote = {
      space: space.address,
      voter: accountWithSigner.address,
      proposalId: { low: '0x1', high: '0x0' },
      choice: '0x1',
      userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }],
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
    };

    const voteSig = (await accountWithSigner.signMessage({
      types: voteTypes,
      primaryType: 'Vote',
      domain: domain,
      message: voteMsg as any,
    } as typedData.TypedData)) as any;

    const voteCalldata = CallData.compile({
      signature: [voteSig.r, voteSig.s],
      ...voteMsg,
    });

    await account.invoke(starkSigAuthenticator, 'authenticate_vote', voteCalldata, {
      rawInput: true,
    });
  }, 1000000);

  it('should revert if an incorrect signature is used', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);

    // Account #1 on Starknet devnet with seed 42
    const invalidAccountWithSigner = new Account(
      new Provider({ sequencer: { baseUrl: network } }),
      '0x7aac39162d91acf2c4f0d539f4b81e23832619ac0c3df9fce22e4a8d505632a',
      '0x23b8c1e9392456de3eb13b9046685257',
    );

    // PROPOSE
    const proposeMsg: Propose = {
      space: space.address,
      author: accountWithSigner.address,
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

    const invalidProposeSig = (await invalidAccountWithSigner.signMessage({
      types: proposeTypes,
      primaryType: 'Propose',
      domain: domain,
      message: proposeMsg as any,
    } as typedData.TypedData)) as any;

    const invalidProposeCalldata = CallData.compile({
      signature: [invalidProposeSig.r, invalidProposeSig.s],
      ...proposeMsg,
    });

    try {
      await account.invoke(starkSigAuthenticator, 'authenticate_propose', invalidProposeCalldata, {
        rawInput: true,
      });
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Invalid Signature'));
    }

    const proposeSig = (await accountWithSigner.signMessage({
      types: proposeTypes,
      primaryType: 'Propose',
      domain: domain,
      message: proposeMsg as any,
    } as typedData.TypedData)) as any;

    const proposeCalldata = CallData.compile({
      signature: [proposeSig.r, proposeSig.s],
      ...proposeMsg,
    });

    await account.invoke(starkSigAuthenticator, 'authenticate_propose', proposeCalldata, {
      rawInput: true,
    });

    // UPDATE PROPOSAL

    const updateProposalMsg: UpdateProposal = {
      space: space.address,
      author: accountWithSigner.address,
      proposalId: { low: '0x1', high: '0x0' },
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x5', '0x6', '0x7', '0x8'],
      },
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x1',
    };

    const invalidUpdateProposalSig = (await invalidAccountWithSigner.signMessage({
      types: updateProposalTypes,
      primaryType: 'UpdateProposal',
      domain: domain,
      message: updateProposalMsg as any,
    } as typedData.TypedData)) as any;

    const invalidUpdateProposalCalldata = CallData.compile({
      signature: [invalidUpdateProposalSig.r, invalidUpdateProposalSig.s],
      ...updateProposalMsg,
    });

    try {
      await account.invoke(
        starkSigAuthenticator,
        'authenticate_update_proposal',
        invalidUpdateProposalCalldata,
        {
          rawInput: true,
        },
      );
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Invalid Signature'));
    }

    const updateProposalSig = (await accountWithSigner.signMessage({
      types: updateProposalTypes,
      primaryType: 'UpdateProposal',
      domain: domain,
      message: updateProposalMsg as any,
    } as typedData.TypedData)) as any;

    const updateProposalCalldata = CallData.compile({
      signature: [updateProposalSig.r, updateProposalSig.s],
      ...updateProposalMsg,
    });

    await account.invoke(
      starkSigAuthenticator,
      'authenticate_update_proposal',
      updateProposalCalldata,
      {
        rawInput: true,
      },
    );

    // Increase time so voting period begins
    await starknet.devnet.increaseTime(100);

    // VOTE

    const voteMsg: Vote = {
      space: space.address,
      voter: accountWithSigner.address,
      proposalId: { low: '0x1', high: '0x0' },
      choice: '0x1',
      userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }],
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
    };

    const invalidVoteSig = (await invalidAccountWithSigner.signMessage({
      types: voteTypes,
      primaryType: 'Vote',
      domain: domain,
      message: voteMsg as any,
    } as typedData.TypedData)) as any;

    const invalidVoteCalldata = CallData.compile({
      signature: [invalidVoteSig.r, invalidVoteSig.s],
      ...voteMsg,
    });

    try {
      await account.invoke(starkSigAuthenticator, 'authenticate_vote', invalidVoteCalldata, {
        rawInput: true,
      });
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Invalid Signature'));
    }

    const voteSig = (await accountWithSigner.signMessage({
      types: voteTypes,
      primaryType: 'Vote',
      domain: domain,
      message: voteMsg as any,
    } as typedData.TypedData)) as any;

    const voteCalldata = CallData.compile({
      signature: [voteSig.r, voteSig.s],
      ...voteMsg,
    });

    await account.invoke(starkSigAuthenticator, 'authenticate_vote', voteCalldata, {
      rawInput: true,
    });
  }, 1000000);

  it('should revert if a salt is reused by an author when creating or updating a proposal', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);

    // PROPOSE
    const proposeMsg: Propose = {
      space: space.address,
      author: accountWithSigner.address,
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

    const proposeSig = (await accountWithSigner.signMessage({
      types: proposeTypes,
      primaryType: 'Propose',
      domain: domain,
      message: proposeMsg as any,
    } as typedData.TypedData)) as any;

    const proposeCalldata = CallData.compile({
      signature: [proposeSig.r, proposeSig.s],
      ...proposeMsg,
    });

    await account.invoke(starkSigAuthenticator, 'authenticate_propose', proposeCalldata, {
      rawInput: true,
    });

    try {
      await account.invoke(starkSigAuthenticator, 'authenticate_propose', proposeCalldata, {
        rawInput: true,
      });
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Salt Already Used'));
    }

    // UPDATE PROPOSAL

    const updateProposalMsg: UpdateProposal = {
      space: space.address,
      author: accountWithSigner.address,
      proposalId: { low: '0x1', high: '0x0' },
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x5', '0x6', '0x7', '0x8'],
      },
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x1',
    };

    const updateProposalSig = (await accountWithSigner.signMessage({
      types: updateProposalTypes,
      primaryType: 'UpdateProposal',
      domain: domain,
      message: updateProposalMsg as any,
    } as typedData.TypedData)) as any;

    const updateProposalCalldata = CallData.compile({
      signature: [updateProposalSig.r, updateProposalSig.s],
      ...updateProposalMsg,
    });

    await account.invoke(
      starkSigAuthenticator,
      'authenticate_update_proposal',
      updateProposalCalldata,
      {
        rawInput: true,
      },
    );

    try {
      await account.invoke(
        starkSigAuthenticator,
        'authenticate_update_proposal',
        updateProposalCalldata,
        {
          rawInput: true,
        },
      );
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Salt Already Used'));
    }
  }, 1000000);
});
