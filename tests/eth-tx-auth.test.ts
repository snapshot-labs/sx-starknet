import { expect } from 'chai';
import dotenv from 'dotenv';
import { poseidonHashMany } from 'micro-starknet';
import { starknet, ethers, network } from 'hardhat';
import { HttpNetworkConfig } from 'hardhat/types';
import { CallData, cairo, shortString, selector } from 'starknet';

dotenv.config();

const eth_network: string = (network.config as HttpNetworkConfig).url;
const account_address = process.env.ADDRESS || '';
const account_pk = process.env.PK || '';

describe('Ethereum Transaction Authenticator', function () {
  this.timeout(1000000);

  let signer: ethers.Wallet;
  let invalidSigner: ethers.Wallet;
  let mockStarknetMessaging: ethers.Contract;
  let starknetCommit: ethers.Contract;

  let account: starknet.starknetAccount;
  let ethTxAuthenticator: starknet.StarknetContract;
  let vanillaVotingStrategy: starknet.StarknetContract;
  let vanillaProposalValidationStrategy: starknet.StarknetContract;
  let space: starknet.StarknetContract;

  before(async function () {
    const commit = `0x${poseidonHashMany([0x1].map((v) => BigInt(v))).toString(16)}`;
    console.log(commit);

    const signers = await ethers.getSigners();
    signer = signers[0];
    invalidSigner = signers[1];

    account = await starknet.OpenZeppelinAccount.getAccountFromAddress(account_address, account_pk);

    // Deploy Mock Starknet Core contract to L1
    const MockStarknetMessaging = await ethers.getContractFactory('MockStarknetMessaging', signer);
    const messageCancellationDelay = 5 * 60; // seconds
    mockStarknetMessaging = await MockStarknetMessaging.deploy(messageCancellationDelay);

    // Deploy Starknet Commit contract to L1
    const starknetCommitFactory = await ethers.getContractFactory('StarknetCommitMockMessaging');
    starknetCommit = await starknetCommitFactory.deploy(mockStarknetMessaging.address);

    const ethSigAuthenticatorFactory = await starknet.getContractFactory('sx_EthTxAuthenticator');
    const vanillaVotingStrategyFactory = await starknet.getContractFactory(
      'sx_VanillaVotingStrategy',
    );
    const vanillaProposalValidationStrategyFactory = await starknet.getContractFactory(
      'sx_VanillaProposalValidationStrategy',
    );
    const spaceFactory = await starknet.getContractFactory('sx_Space');

    try {
      // If the contracts are already declared, this will be skipped
      await account.declare(ethSigAuthenticatorFactory);
      await account.declare(vanillaVotingStrategyFactory);
      await account.declare(vanillaProposalValidationStrategyFactory);
      await account.declare(spaceFactory);
    } catch {}

    ethTxAuthenticator = await account.deploy(ethSigAuthenticatorFactory, {
      starknet_commit_address: starknetCommit.address,
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
      _authenticators: [ethTxAuthenticator.address],
      _metadata_uri: [],
      _dao_uri: [],
    });

    await account.invoke(space, 'initialize', initializeCalldata, { rawInput: true });

    // Dumping the Starknet state so it can be loaded at the same point for each test
    await starknet.devnet.dump('dump.pkl');
  }, 10000000);

  it('can authenticate a proposal, a vote, and a proposal update', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const proposal = {
      author: signer.address,
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
    };

    const proposeCommitPreImage = CallData.compile({
      target: space.address,
      selector: selector.getSelectorFromName('propose'),
      ...proposal,
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const commit = `0x${poseidonHashMany(proposeCommitPreImage.map((v) => BigInt(v))).toString(
      16,
    )}`;

    await starknetCommit.commit(ethTxAuthenticator.address, commit, { value: 18485000000000 });

    // Checking that the L1 -> L2 message has been propagated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    await account.invoke(
      ethTxAuthenticator,
      'authenticate_propose',
      CallData.compile({
        target: space.address,
        author: proposal.author,
        metadataURI: proposal.metadataUri,
        executionStrategy: proposal.executionStrategy,
        userProposalValidationParams: proposal.userProposalValidationParams,
      }),
      { rawInput: true },
    );

    const updateProposal = {
      author: signer.address,
      proposalId: cairo.uint256('0x1'),
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x0'],
      },
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
    };

    const updateCommitPreImage = CallData.compile({
      target: space.address,
      selector: selector.getSelectorFromName('update_proposal'),
      ...updateProposal,
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const updateCommit = `0x${poseidonHashMany(updateCommitPreImage.map((v) => BigInt(v))).toString(
      16,
    )}`;

    await starknetCommit.commit(ethTxAuthenticator.address, updateCommit, {
      value: 18485000000000,
    });

    // Checking that the L1 -> L2 message has been propagated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    await account.invoke(
      ethTxAuthenticator,
      'authenticate_update_proposal',
      CallData.compile({
        target: space.address,
        author: updateProposal.author,
        proposalId: updateProposal.proposalId,
        executionStrategy: updateProposal.executionStrategy,
        metadataURI: updateProposal.metadataUri,
      }),
      { rawInput: true },
    );

    // Increase time so voting period begins
    await starknet.devnet.increaseTime(100);

    const vote = {
      voter: signer.address,
      proposalId: cairo.uint256('0x1'),
      choice: '0x1',
      userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }],
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
    };

    const voteCommitPreImage = CallData.compile({
      target: space.address,
      selector: selector.getSelectorFromName('vote'),
      ...vote,
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const voteCommit = `0x${poseidonHashMany(voteCommitPreImage.map((v) => BigInt(v))).toString(
      16,
    )}`;

    await starknetCommit.commit(ethTxAuthenticator.address, voteCommit, { value: 18485000000000 });

    // Checking that the L1 -> L2 message has been propagated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    await account.invoke(
      ethTxAuthenticator,
      'authenticate_vote',
      CallData.compile({
        target: space.address,
        voter: vote.voter,
        proposalId: vote.proposalId,
        choice: vote.choice,
        userVotingStrategies: vote.userVotingStrategies,
        metadataURI: vote.metadataUri,
      }),
      { rawInput: true },
    );
  }, 1000000);

  it('should revert if an invalid hash of an action was committed', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const proposal = {
      author: signer.address,
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
    };

    const proposeCommitPreImage = CallData.compile({
      target: space.address,
      selector: selector.getSelectorFromName('propose'),
      ...proposal,
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const commit = `0x${poseidonHashMany(proposeCommitPreImage.map((v) => BigInt(v))).toString(
      16,
    )}`;

    await starknetCommit.commit(ethTxAuthenticator.address, commit, { value: 18485000000000 });

    // Checking that the L1 -> L2 message has been propogated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    // Try to authenticate with an invalid author
    try {
      await account.invoke(
        ethTxAuthenticator,
        'authenticate_propose',
        CallData.compile({
          target: space.address,
          author: invalidSigner.address,
          metadataURI: proposal.metadataUri,
          executionStrategy: proposal.executionStrategy,
          userProposalValidationParams: proposal.userProposalValidationParams,
        }),
        { rawInput: true },
      );
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Commit not found'));
    }

    await account.invoke(
      ethTxAuthenticator,
      'authenticate_propose',
      CallData.compile({
        target: space.address,
        author: proposal.author,
        metadataURI: proposal.metadataUri,
        executionStrategy: proposal.executionStrategy,
        userProposalValidationParams: proposal.userProposalValidationParams,
      }),
      { rawInput: true },
    );

    const updateProposal = {
      author: signer.address,
      proposalId: cairo.uint256('0x1'),
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x0'],
      },
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
    };

    const updateCommitPreImage = CallData.compile({
      target: space.address,
      selector: selector.getSelectorFromName('update_proposal'),
      ...updateProposal,
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const updateCommit = `0x${poseidonHashMany(updateCommitPreImage.map((v) => BigInt(v))).toString(
      16,
    )}`;

    await starknetCommit.commit(ethTxAuthenticator.address, updateCommit, {
      value: 18485000000000,
    });

    // Checking that the L1 -> L2 message has been propogated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    try {
      await account.invoke(
        ethTxAuthenticator,
        'authenticate_update_proposal',
        CallData.compile({
          target: space.address,
          author: invalidSigner.address,
          proposalId: updateProposal.proposalId,
          executionStrategy: updateProposal.executionStrategy,
          metadataURI: updateProposal.metadataUri,
        }),
        { rawInput: true },
      );

      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Commit not found'));
    }

    await account.invoke(
      ethTxAuthenticator,
      'authenticate_update_proposal',
      CallData.compile({
        target: space.address,
        author: updateProposal.author,
        proposalId: updateProposal.proposalId,
        executionStrategy: updateProposal.executionStrategy,
        metadataURI: updateProposal.metadataUri,
      }),
      { rawInput: true },
    );

    // Increase time so voting period begins
    await starknet.devnet.increaseTime(100);

    const vote = {
      voter: signer.address,
      proposalId: cairo.uint256('0x1'),
      choice: '0x1',
      userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }],
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
    };

    const voteCommitPreImage = CallData.compile({
      target: space.address,
      selector: selector.getSelectorFromName('vote'),
      ...vote,
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const voteCommit = `0x${poseidonHashMany(voteCommitPreImage.map((v) => BigInt(v))).toString(
      16,
    )}`;

    await starknetCommit.commit(ethTxAuthenticator.address, voteCommit, { value: 18485000000000 });

    // Checking that the L1 -> L2 message has been propogated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    try {
      await account.invoke(
        ethTxAuthenticator,
        'authenticate_vote',
        CallData.compile({
          target: space.address,
          voter: invalidSigner.address,
          proposalId: vote.proposalId,
          choice: vote.choice,
          userVotingStrategies: vote.userVotingStrategies,
          metadataURI: vote.metadataUri,
        }),
        { rawInput: true },
      );
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Commit not found'));
    }

    await account.invoke(
      ethTxAuthenticator,
      'authenticate_vote',
      CallData.compile({
        target: space.address,
        voter: vote.voter,
        proposalId: vote.proposalId,
        choice: vote.choice,
        userVotingStrategies: vote.userVotingStrategies,
        metadataURI: vote.metadataUri,
      }),
      { rawInput: true },
    );
  }, 1000000);

  it('should revert if a commit was made by a different address to the author/voter address', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const proposal = {
      author: signer.address,
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
    };

    const proposeCommitPreImage = CallData.compile({
      target: space.address,
      selector: selector.getSelectorFromName('propose'),
      ...proposal,
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const commit = `0x${poseidonHashMany(proposeCommitPreImage.map((v) => BigInt(v))).toString(
      16,
    )}`;

    // Committing payload from a different address to the author
    await starknetCommit
      .connect(invalidSigner)
      .commit(ethTxAuthenticator.address, commit, { value: 18485000000000 });

    // Checking that the L1 -> L2 message has been propogated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    try {
      await account.invoke(
        ethTxAuthenticator,
        'authenticate_propose',
        CallData.compile({
          target: space.address,
          author: proposal.author,
          metadataURI: proposal.metadataUri,
          executionStrategy: proposal.executionStrategy,
          userProposalValidationParams: proposal.userProposalValidationParams,
        }),
        { rawInput: true },
      );
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Invalid sender address'));
    }
  }, 1000000);

  it('a commit cannot be consumed twice', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const proposal = {
      author: signer.address,
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
    };

    const proposeCommitPreImage = CallData.compile({
      target: space.address,
      selector: selector.getSelectorFromName('propose'),
      ...proposal,
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const commit = `0x${poseidonHashMany(proposeCommitPreImage.map((v) => BigInt(v))).toString(
      16,
    )}`;

    // Committing payload from a different address to the author
    await starknetCommit.commit(ethTxAuthenticator.address, commit, { value: 18485000000000 });

    // Checking that the L1 -> L2 message has been propogated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    await account.invoke(
      ethTxAuthenticator,
      'authenticate_propose',
      CallData.compile({
        target: space.address,
        author: proposal.author,
        metadataURI: proposal.metadataUri,
        executionStrategy: proposal.executionStrategy,
        userProposalValidationParams: proposal.userProposalValidationParams,
      }),
      { rawInput: true },
    );

    // Attempting to replay the proposal creation commit
    try {
      await account.invoke(
        ethTxAuthenticator,
        'authenticate_propose',
        CallData.compile({
          target: space.address,
          author: proposal.author,
          metadataURI: proposal.metadataUri,
          executionStrategy: proposal.executionStrategy,
          userProposalValidationParams: proposal.userProposalValidationParams,
        }),
        { rawInput: true },
      );
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Commit not found'));
    }
  }, 1000000);

  it('a commit cannot be overwritten by a different sender', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const proposal = {
      author: signer.address,
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
    };

    const proposeCommitPreImage = CallData.compile({
      target: space.address,
      selector: selector.getSelectorFromName('propose'),
      ...proposal,
    });

    // Commit hash of payload to the Starknet Commit L1 contract
    const commit = `0x${poseidonHashMany(proposeCommitPreImage.map((v) => BigInt(v))).toString(
      16,
    )}`;

    await starknetCommit.commit(ethTxAuthenticator.address, commit, { value: 18485000000000 });

    // Committing the same commit but different sender
    await starknetCommit
      .connect(invalidSigner)
      .commit(ethTxAuthenticator.address, commit, { value: 18485000000000 });

    // Checking that both L1 -> L2 messages has been propogated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(2);

    // The commit by the correct signer should be accepted
    await account.invoke(
      ethTxAuthenticator,
      'authenticate_propose',
      CallData.compile({
        target: space.address,
        author: proposal.author,
        metadataURI: proposal.metadataUri,
        executionStrategy: proposal.executionStrategy,
        userProposalValidationParams: proposal.userProposalValidationParams,
      }),
      { rawInput: true },
    );
  }, 1000000);
});
