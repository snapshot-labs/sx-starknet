import { expect } from 'chai';
import dotenv from 'dotenv';
import { poseidonHashMany } from 'micro-starknet';
import { starknet, ethers, network } from 'hardhat';
import { HttpNetworkConfig } from 'hardhat/types';
import { CallData, cairo, shortString, selector, Account, typedData, Provider } from 'starknet';
import {
  Propose,
  proposeTypes,
  UpdateProposal,
  updateProposalTypes,
  Vote,
  voteTypes,
} from './stark-sig-types';

dotenv.config();

const eth_network: string = (network.config as HttpNetworkConfig).url;
const stark_network = process.env.STARKNET_NETWORK_URL || '';
const account_address = process.env.ADDRESS || '';
const account_pk = process.env.PK || '';
const account_public_key = process.env.PUBLIC_KEY || '';

describe('Ethereum Transaction Authenticator', function () {
  this.timeout(1000000);

  let ethSigner: ethers.Wallet;
  let invalidSigner: ethers.Wallet;
  let mockStarknetMessaging: ethers.Contract;
  let starknetCommit: ethers.Contract;
  // Account used to submit transactions
  let manaAccount: starknet.starknetAccount;
  // SNIP-6 compliant account (the defaults deployed on the devnet are not SNIP-6 compliant and therefore cannot be used for signatures)
  let sessionAccountWithSigner: Account;
  let ethTxSessionKeyAuthenticator: starknet.StarknetContract;
  let vanillaVotingStrategy: starknet.StarknetContract;
  let vanillaProposalValidationStrategy: starknet.StarknetContract;
  let space: starknet.StarknetContract;

  let starkDomain: any;

  before(async function () {
    const commit = `0x${poseidonHashMany([0x1].map((v) => BigInt(v))).toString(16)}`;

    const signers = await ethers.getSigners();
    ethSigner = signers[0];
    invalidSigner = signers[1];

    manaAccount = await starknet.OpenZeppelinAccount.getAccountFromAddress(
      account_address,
      account_pk,
    );

    sessionAccountWithSigner = new Account(
      new Provider({ sequencer: { baseUrl: stark_network } }),
      '0x1',
      account_pk,
    );

    // Deploy Mock Starknet Core contract to L1
    const MockStarknetMessaging = await ethers.getContractFactory(
      'MockStarknetMessaging',
      ethSigner,
    );
    const messageCancellationDelay = 5 * 60; // seconds
    mockStarknetMessaging = await MockStarknetMessaging.deploy(messageCancellationDelay);

    // Deploy Starknet Commit contract to L1
    const starknetCommitFactory = await ethers.getContractFactory('StarknetCommitMockMessaging');
    starknetCommit = await starknetCommitFactory.deploy(mockStarknetMessaging.address);

    const ethTxSessionKeyAuthenticatorFactory = await starknet.getContractFactory(
      'sx_EthTxSessionKeyAuthenticator',
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
      await manaAccount.declare(ethTxSessionKeyAuthenticatorFactory);
      await manaAccount.declare(vanillaVotingStrategyFactory);
      await manaAccount.declare(vanillaProposalValidationStrategyFactory);
      await manaAccount.declare(spaceFactory);
    } catch {}

    ethTxSessionKeyAuthenticator = await manaAccount.deploy(ethTxSessionKeyAuthenticatorFactory, {
      name: shortString.encodeShortString('sx-sn'),
      version: shortString.encodeShortString('0.1.0'),
      starknet_commit_address: starknetCommit.address,
    });

    starkDomain = {
      name: 'sx-sn',
      version: '0.1.0',
      chainId: '0x534e5f474f45524c49', // devnet id
      verifyingContract: ethTxSessionKeyAuthenticator.address,
    };

    vanillaVotingStrategy = await manaAccount.deploy(vanillaVotingStrategyFactory);
    vanillaProposalValidationStrategy = await manaAccount.deploy(
      vanillaProposalValidationStrategyFactory,
    );
    space = await manaAccount.deploy(spaceFactory);

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
      _authenticators: [ethTxSessionKeyAuthenticator.address],
      _metadata_uri: [],
      _dao_uri: [],
    });

    await manaAccount.invoke(space, 'initialize', initializeCalldata, { rawInput: true });

    // Dumping the Starknet state so it can be loaded at the same point for each test
    await starknet.devnet.dump('dump.pkl');
  }, 10000000);

  it('can register a session then authenticate a proposal, a vote, and a proposal update with that session', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const registerSessionCommitPreImage = CallData.compile({
      authenticator: ethTxSessionKeyAuthenticator.address,
      selector: shortString.encodeShortString('register_session'),
      owner: ethSigner.address,
      sessionPublicKey: account_public_key,
      session_duration: '0x123',
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const commit = `0x${poseidonHashMany(
      registerSessionCommitPreImage.map((v) => BigInt(v)),
    ).toString(16)}`;

    await starknetCommit.commit(ethTxSessionKeyAuthenticator.address, commit, {
      value: 18485000000000,
    });

    // Checking that the L1 -> L2 message has been propagated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    await manaAccount.invoke(
      ethTxSessionKeyAuthenticator,
      'register_with_owner_tx',
      CallData.compile({
        owner: ethSigner.address,
        sessionPublicKey: account_public_key,
        session_duration: '0x123',
      }),
      { rawInput: true },
    );

    // Propose
    const proposeMsg: Propose = {
      space: space.address,
      author: ethSigner.address,
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
      salt: '0x1',
    };
    const proposeSig = (await sessionAccountWithSigner.signMessage({
      types: proposeTypes,
      primaryType: 'Propose',
      domain: starkDomain,
      message: proposeMsg as any,
    } as typedData.TypedData)) as any;
    const proposeCalldata = CallData.compile({
      signature: [proposeSig.r, proposeSig.s],
      ...proposeMsg,
      session_public_key: account_public_key,
    });
    await manaAccount.invoke(
      ethTxSessionKeyAuthenticator,
      'authenticate_propose',
      proposeCalldata,
      {
        rawInput: true,
      },
    );
    // UPDATE PROPOSAL
    const updateProposalMsg: UpdateProposal = {
      space: space.address,
      author: ethSigner.address,
      proposalId: { low: '0x1', high: '0x0' },
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x5', '0x6', '0x7', '0x8'],
      },
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x2',
    };
    const updateProposalSig = (await sessionAccountWithSigner.signMessage({
      types: updateProposalTypes,
      primaryType: 'UpdateProposal',
      domain: starkDomain,
      message: updateProposalMsg as any,
    } as typedData.TypedData)) as any;
    const updateProposalCalldata = CallData.compile({
      signature: [updateProposalSig.r, updateProposalSig.s],
      ...updateProposalMsg,
      session_public_key: account_public_key,
    });
    await manaAccount.invoke(
      ethTxSessionKeyAuthenticator,
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
      voter: ethSigner.address,
      proposalId: { low: '0x1', high: '0x0' },
      choice: '0x1',
      userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }],
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
    };
    const voteSig = (await sessionAccountWithSigner.signMessage({
      types: voteTypes,
      primaryType: 'Vote',
      domain: starkDomain,
      message: voteMsg as any,
    } as typedData.TypedData)) as any;
    const voteCalldata = CallData.compile({
      signature: [voteSig.r, voteSig.s],
      ...voteMsg,
      session_public_key: account_public_key,
    });
    await manaAccount.invoke(ethTxSessionKeyAuthenticator, 'authenticate_vote', voteCalldata, {
      rawInput: true,
    });
  }, 1000000);

  it('should revert if an invalid hash of an action was committed', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const registerSessionCommitPreImage = CallData.compile({
      authenticator: ethTxSessionKeyAuthenticator.address,
      selector: shortString.encodeShortString('register_session'),
      owner: ethSigner.address,
      sessionPublicKey: account_public_key,
      session_duration: '0x123',
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const commit = `0x${poseidonHashMany(
      registerSessionCommitPreImage.map((v) => BigInt(v)),
    ).toString(16)}`;

    await starknetCommit.commit(ethTxSessionKeyAuthenticator.address, commit, {
      value: 18485000000000,
    });

    // Checking that the L1 -> L2 message has been propagated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    // Invalid owner
    try {
      await manaAccount.invoke(
        ethTxSessionKeyAuthenticator,
        'register_with_owner_tx',
        CallData.compile({
          owner: invalidSigner.address,
          sessionPublicKey: account_public_key,
          session_duration: '0x123',
        }),
        { rawInput: true },
      );
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Commit not found'));
    }
  }, 1000000);

  it('can revoke a session with an owner tx', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    // Register a session
    const registerSessionCommitPreImage = CallData.compile({
      authenticator: ethTxSessionKeyAuthenticator.address,
      selector: shortString.encodeShortString('register_session'),
      owner: ethSigner.address,
      sessionPublicKey: account_public_key,
      session_duration: '0x123',
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const commit = `0x${poseidonHashMany(
      registerSessionCommitPreImage.map((v) => BigInt(v)),
    ).toString(16)}`;

    await starknetCommit.commit(ethTxSessionKeyAuthenticator.address, commit, {
      value: 18485000000000,
    });

    // Checking that the L1 -> L2 message has been propagated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    await manaAccount.invoke(
      ethTxSessionKeyAuthenticator,
      'register_with_owner_tx',
      CallData.compile({
        owner: ethSigner.address,
        sessionPublicKey: account_public_key,
        session_duration: '0x123',
      }),
      { rawInput: true },
    );

    const revokeSessionCommitPreImage = CallData.compile({
      authenticator: ethTxSessionKeyAuthenticator.address,
      selector: shortString.encodeShortString('revoke_session'),
      owner: ethSigner.address,
      sessionPublicKey: account_public_key,
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const revokeCommit = `0x${poseidonHashMany(
      revokeSessionCommitPreImage.map((v) => BigInt(v)),
    ).toString(16)}`;

    await starknetCommit.commit(ethTxSessionKeyAuthenticator.address, revokeCommit, {
      value: 18485000000000,
    });

    // Checking that the L1 -> L2 message has been propagated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    await manaAccount.invoke(
      ethTxSessionKeyAuthenticator,
      'revoke_with_owner_tx',
      CallData.compile({
        owner: ethSigner.address,
        sessionPublicKey: account_public_key,
      }),
      { rawInput: true },
    );
  }, 1000000);

  it('can revoke a session with an session key sig', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    // Register a session
    const registerSessionCommitPreImage = CallData.compile({
      authenticator: ethTxSessionKeyAuthenticator.address,
      selector: shortString.encodeShortString('register_session'),
      owner: ethSigner.address,
      sessionPublicKey: account_public_key,
      session_duration: '0x123',
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const commit = `0x${poseidonHashMany(
      registerSessionCommitPreImage.map((v) => BigInt(v)),
    ).toString(16)}`;

    await starknetCommit.commit(ethTxSessionKeyAuthenticator.address, commit, {
      value: 18485000000000,
    });

    // Checking that the L1 -> L2 message has been propagated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    await manaAccount.invoke(
      ethTxSessionKeyAuthenticator,
      'register_with_owner_tx',
      CallData.compile({
        owner: ethSigner.address,
        sessionPublicKey: account_public_key,
        session_duration: '0x123',
      }),
      { rawInput: true },
    );
  }, 1000000);

  it('will revert if incorrect signatures are used', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    // Register a session
    const registerSessionCommitPreImage = CallData.compile({
      authenticator: ethTxSessionKeyAuthenticator.address,
      selector: shortString.encodeShortString('register_session'),
      owner: ethSigner.address,
      sessionPublicKey: account_public_key,
      session_duration: '0x123',
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const commit = `0x${poseidonHashMany(
      registerSessionCommitPreImage.map((v) => BigInt(v)),
    ).toString(16)}`;

    await starknetCommit.commit(ethTxSessionKeyAuthenticator.address, commit, {
      value: 18485000000000,
    });

    // Checking that the L1 -> L2 message has been propagated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    await manaAccount.invoke(
      ethTxSessionKeyAuthenticator,
      'register_with_owner_tx',
      CallData.compile({
        owner: ethSigner.address,
        sessionPublicKey: account_public_key,
        session_duration: '0x123',
      }),
      { rawInput: true },
    );

    // Account #1 on Starknet devnet with seed 42
    const invalidAccountWithSigner = new Account(
      new Provider({ sequencer: { baseUrl: stark_network } }),
      '0x7aac39162d91acf2c4f0d539f4b81e23832619ac0c3df9fce22e4a8d505632a',
      '0x23b8c1e9392456de3eb13b9046685257',
    );

    // Attempt to propose
    const proposeMsg: Propose = {
      space: space.address,
      author: ethSigner.address,
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
      salt: '0x1',
    };

    const invalidProposeSig = (await invalidAccountWithSigner.signMessage({
      types: proposeTypes,
      primaryType: 'Propose',
      domain: starkDomain,
      message: proposeMsg as any,
    } as typedData.TypedData)) as any;

    const invalidProposeCalldata = CallData.compile({
      signature: [invalidProposeSig.r, invalidProposeSig.s],
      ...proposeMsg,
      session_public_key: account_public_key,
    });

    try {
      await manaAccount.invoke(
        ethTxSessionKeyAuthenticator,
        'authenticate_propose',
        invalidProposeCalldata,
        {
          rawInput: true,
        },
      );
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Invalid Signature'));
    }

    // Actually creating a proposal
    const proposeSig = (await sessionAccountWithSigner.signMessage({
      types: proposeTypes,
      primaryType: 'Propose',
      domain: starkDomain,
      message: proposeMsg as any,
    } as typedData.TypedData)) as any;

    const proposeCalldata = CallData.compile({
      signature: [proposeSig.r, proposeSig.s],
      ...proposeMsg,
      session_public_key: account_public_key,
    });
    await manaAccount.invoke(
      ethTxSessionKeyAuthenticator,
      'authenticate_propose',
      proposeCalldata,
      {
        rawInput: true,
      },
    );
    // Attempt to update proposal
    const updateProposalMsg: UpdateProposal = {
      space: space.address,
      author: ethSigner.address,
      proposalId: { low: '0x1', high: '0x0' },
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x5', '0x6', '0x7', '0x8'],
      },
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x2',
    };

    const invalidUpdateProposalSig = (await invalidAccountWithSigner.signMessage({
      types: updateProposalTypes,
      primaryType: 'UpdateProposal',
      domain: starkDomain,
      message: updateProposalMsg as any,
    } as typedData.TypedData)) as any;

    const invalidUpdateProposalCalldata = CallData.compile({
      signature: [invalidUpdateProposalSig.r, invalidUpdateProposalSig.s],
      ...updateProposalMsg,
      session_public_key: account_public_key,
    });

    try {
      await manaAccount.invoke(
        ethTxSessionKeyAuthenticator,
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

    // Increase time so voting period begins
    await starknet.devnet.increaseTime(100);

    // Attempt to Vote
    const voteMsg: Vote = {
      space: space.address,
      voter: ethSigner.address,
      proposalId: { low: '0x1', high: '0x0' },
      choice: '0x1',
      userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }],
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
    };

    const invalidVoteSig = (await invalidAccountWithSigner.signMessage({
      types: voteTypes,
      primaryType: 'Vote',
      domain: starkDomain,
      message: voteMsg as any,
    } as typedData.TypedData)) as any;

    const invalidVoteCalldata = CallData.compile({
      signature: [invalidVoteSig.r, invalidVoteSig.s],
      ...voteMsg,
      session_public_key: account_public_key,
    });

    try {
      await manaAccount.invoke(
        ethTxSessionKeyAuthenticator,
        'authenticate_vote',
        invalidVoteCalldata,
        {
          rawInput: true,
        },
      );
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Invalid Signature'));
    }
  }, 1000000);

  it('The session cannot be used if it has expired', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const registerSessionCommitPreImage = CallData.compile({
      authenticator: ethTxSessionKeyAuthenticator.address,
      selector: shortString.encodeShortString('register_session'),
      owner: ethSigner.address,
      sessionPublicKey: account_public_key,
      session_duration: '0x1',
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const commit = `0x${poseidonHashMany(
      registerSessionCommitPreImage.map((v) => BigInt(v)),
    ).toString(16)}`;

    await starknetCommit.commit(ethTxSessionKeyAuthenticator.address, commit, {
      value: 18485000000000,
    });

    // Checking that the L1 -> L2 message has been propagated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    await manaAccount.invoke(
      ethTxSessionKeyAuthenticator,
      'register_with_owner_tx',
      CallData.compile({
        owner: ethSigner.address,
        sessionPublicKey: account_public_key,
        session_duration: '0x1',
      }),
      { rawInput: true },
    );

    // Increase time to expire the session
    await starknet.devnet.increaseTime(100);

    // Try to Propose
    const proposeMsg: Propose = {
      space: space.address,
      author: ethSigner.address,
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
      salt: '0x1',
    };
    const proposeSig = (await sessionAccountWithSigner.signMessage({
      types: proposeTypes,
      primaryType: 'Propose',
      domain: starkDomain,
      message: proposeMsg as any,
    } as typedData.TypedData)) as any;
    const proposeCalldata = CallData.compile({
      signature: [proposeSig.r, proposeSig.s],
      ...proposeMsg,
      session_public_key: account_public_key,
    });
    // Proposing should fail because the session is revoked
    try {
      await manaAccount.invoke(
        ethTxSessionKeyAuthenticator,
        'authenticate_propose',
        proposeCalldata,
        {
          rawInput: true,
        },
      );
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Session key expired'));
    }
  }, 1000000);
});
