import dotenv from 'dotenv';
import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { CallData, typedData, cairo, shortString, Account, Provider } from 'starknet';
import {
  sessionKeyAuthTypes,
  SessionKeyAuth,
  sessionKeyRevokeTypes,
  SessionKeyRevoke,
} from './stark-sig-types';
import {
  proposeTypes,
  Propose,
  updateProposalTypes,
  UpdateProposal,
  voteTypes,
  Vote,
  sessionKeyRevokeTypes as sessionKeyRevokeTypesStark,
  SessionKeyRevoke as SessionKeyRevokeStark,
} from './stark-sig-types';
import { getRSVFromSig } from './utils';

dotenv.config();

const account_address = process.env.ADDRESS || '';
const account_pk = process.env.PK || '';
const account_public_key = process.env.PUBLIC_KEY || '';
const network = process.env.STARKNET_NETWORK_URL || '';

describe('Ethereum Signature Session Key Authenticator', function () {
  this.timeout(1000000);

  // Account used to submit transactions
  let manaAccount: starknet.starknetAccount;
  let sessionOwnerAccount: starknet.starknetAccount;
  // SNIP-6 compliant account (the defaults deployed on the devnet are not SNIP-6 compliant and therefore cannot be used for signatures)
  let sessionAccountWithSigner: Account;
  let starkTxSessionKeyAuthenticator: starknet.StarknetContract;
  let vanillaVotingStrategy: starknet.StarknetContract;
  let vanillaProposalValidationStrategy: starknet.StarknetContract;
  let space: starknet.StarknetContract;

  let starkDomain: any;

  before(async function () {
    manaAccount = await starknet.OpenZeppelinAccount.getAccountFromAddress(
      account_address,
      account_pk,
    );

    // Account #2 on Starknet devnet with seed 42
    sessionOwnerAccount = await starknet.OpenZeppelinAccount.getAccountFromAddress(
      '0x9c4ba7b103329632f6bf5035f1e440b341e7477c4231a47b15545b19d23f76',
      '0xbd9c66b3ad3c2d6d1a3d1fa7bc8960a9',
    );

    const accountFactory = await starknet.getContractFactory('openzeppelin_Account');
    const starkTxSessionKeyAuthenticatorFactory = await starknet.getContractFactory(
      'sx_StarkTxSessionKeyAuthenticator',
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
      await manaAccount.declare(accountFactory);
      await manaAccount.declare(starkTxSessionKeyAuthenticatorFactory);
      await manaAccount.declare(vanillaVotingStrategyFactory);
      await manaAccount.declare(vanillaProposalValidationStrategyFactory);
      await manaAccount.declare(spaceFactory);
    } catch {}

    starkTxSessionKeyAuthenticator = await manaAccount.deploy(
      starkTxSessionKeyAuthenticatorFactory,
      {
        name: shortString.encodeShortString('sx-sn'),
        version: shortString.encodeShortString('0.1.0'),
      },
    );

    starkDomain = {
      name: 'sx-sn',
      version: '0.1.0',
      chainId: '0x534e5f474f45524c49', // devnet id
      verifyingContract: starkTxSessionKeyAuthenticator.address,
    };

    // Dummy account wrapper to sign messages
    sessionAccountWithSigner = new Account(
      new Provider({ sequencer: { baseUrl: network } }),
      '0x1',
      account_pk,
    );

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
      _authenticators: [starkTxSessionKeyAuthenticator.address],
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
    // Register Session
    const sessionKeyAuthCalldata = CallData.compile({
      owner: sessionOwnerAccount.address,
      sessionPublicKey: account_public_key,
      sessionDuration: '0x123',
    });
    await sessionOwnerAccount.invoke(
      starkTxSessionKeyAuthenticator,
      'register_with_owner_tx',
      sessionKeyAuthCalldata,
      {
        rawInput: true,
      },
    );
    // Propose
    const proposeMsg: Propose = {
      space: space.address,
      author: sessionOwnerAccount.address,
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
      starkTxSessionKeyAuthenticator,
      'authenticate_propose',
      proposeCalldata,
      {
        rawInput: true,
      },
    );
    // UPDATE PROPOSAL
    const updateProposalMsg: UpdateProposal = {
      space: space.address,
      author: sessionOwnerAccount.address,
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
      starkTxSessionKeyAuthenticator,
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
      voter: sessionOwnerAccount.address,
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
    await manaAccount.invoke(starkTxSessionKeyAuthenticator, 'authenticate_vote', voteCalldata, {
      rawInput: true,
    });
  }, 1000000);

  it('will revert if incorrect signatures are used', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    // Register Session
    const sessionKeyAuthCalldata = CallData.compile({
      owner: sessionOwnerAccount.address,
      sessionPublicKey: account_public_key,
      sessionDuration: '0x123',
    });
    await sessionOwnerAccount.invoke(
      starkTxSessionKeyAuthenticator,
      'register_with_owner_tx',
      sessionKeyAuthCalldata,
      {
        rawInput: true,
      },
    );

    // Account #1 on Starknet devnet with seed 42
    const invalidAccountWithSigner = new Account(
      new Provider({ sequencer: { baseUrl: network } }),
      '0x7aac39162d91acf2c4f0d539f4b81e23832619ac0c3df9fce22e4a8d505632a',
      '0x23b8c1e9392456de3eb13b9046685257',
    );

    // Attempt to propose
    const proposeMsg: Propose = {
      space: space.address,
      author: sessionOwnerAccount.address,
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
        starkTxSessionKeyAuthenticator,
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
      starkTxSessionKeyAuthenticator,
      'authenticate_propose',
      proposeCalldata,
      {
        rawInput: true,
      },
    );
    // Attempt to update proposal
    const updateProposalMsg: UpdateProposal = {
      space: space.address,
      author: sessionOwnerAccount.address,
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
        starkTxSessionKeyAuthenticator,
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
      voter: sessionOwnerAccount.address,
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
        starkTxSessionKeyAuthenticator,
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

  it('can revoke a session with an owner tx', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    // Register Session
    const sessionKeyAuthCalldata = CallData.compile({
      owner: sessionOwnerAccount.address,
      sessionPublicKey: account_public_key,
      sessionDuration: '0x123',
    });
    await sessionOwnerAccount.invoke(
      starkTxSessionKeyAuthenticator,
      'register_with_owner_tx',
      sessionKeyAuthCalldata,
      {
        rawInput: true,
      },
    );

    // Revoke Session
    const revokeSessionCalldata = CallData.compile({
      owner: sessionOwnerAccount.address,
      sessionPublicKey: account_public_key,
    });
    await sessionOwnerAccount.invoke(
      starkTxSessionKeyAuthenticator,
      'revoke_with_owner_tx',
      revokeSessionCalldata,
      {
        rawInput: true,
      },
    );
  }, 1000000);

  it('can revoke a session with an session key sig', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    // Register Session
    const sessionKeyAuthCalldata = CallData.compile({
      owner: sessionOwnerAccount.address,
      sessionPublicKey: account_public_key,
      sessionDuration: '0x123',
    });
    await sessionOwnerAccount.invoke(
      starkTxSessionKeyAuthenticator,
      'register_with_owner_tx',
      sessionKeyAuthCalldata,
      {
        rawInput: true,
      },
    );

    // Revoke Session with session key sig
    const revokeSessionMsg: SessionKeyRevokeStark = {
      owner: sessionOwnerAccount.address,
      sessionPublicKey: account_public_key,
      salt: '0x1',
    };
    const revokeSessionKeySig = (await sessionAccountWithSigner.signMessage({
      types: sessionKeyRevokeTypesStark,
      primaryType: 'SessionKeyRevoke',
      domain: starkDomain,
      message: revokeSessionMsg as any,
    } as typedData.TypedData)) as any;
    const revokeSessionCalldata = CallData.compile({
      signature: [revokeSessionKeySig.r, revokeSessionKeySig.s],
      owner: revokeSessionMsg.owner,
      sessionPublicKey: revokeSessionMsg.sessionPublicKey,
      salt: revokeSessionMsg.salt,
    });
    await manaAccount.invoke(
      starkTxSessionKeyAuthenticator,
      'revoke_with_session_key_sig',
      revokeSessionCalldata,
      {
        rawInput: true,
      },
    );
    // Try to Propose
    const proposeMsg: Propose = {
      space: space.address,
      author: sessionOwnerAccount.address,
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
        starkTxSessionKeyAuthenticator,
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

  it('The session cannot be used if it has expired', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    // Register Session
    const sessionKeyAuthCalldata = CallData.compile({
      owner: sessionOwnerAccount.address,
      sessionPublicKey: account_public_key,
      sessionDuration: '0x1',
    });
    await sessionOwnerAccount.invoke(
      starkTxSessionKeyAuthenticator,
      'register_with_owner_tx',
      sessionKeyAuthCalldata,
      {
        rawInput: true,
      },
    );

    // Increase time to expire the session
    await starknet.devnet.increaseTime(100);

    // Try to Propose
    const proposeMsg: Propose = {
      space: space.address,
      author: sessionOwnerAccount.address,
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
        starkTxSessionKeyAuthenticator,
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

  it('The register/revoke tx must be submitted by the session owner', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    // Try to Register Session through mana account
    const sessionKeyAuthCalldata = CallData.compile({
      owner: sessionOwnerAccount.address,
      sessionPublicKey: account_public_key,
      sessionDuration: '0x123',
    });
    try {
      await manaAccount.invoke(
        starkTxSessionKeyAuthenticator,
        'register_with_owner_tx',
        sessionKeyAuthCalldata,
        {
          rawInput: true,
        },
      );
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Invalid Caller'));
    }
  }, 1000000);
});
