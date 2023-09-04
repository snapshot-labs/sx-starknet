import dotenv from 'dotenv';
import { expect } from 'chai';
import { starknet, ethers, network } from 'hardhat';
import { HttpNetworkConfig } from 'hardhat/types';
import { CallData, Uint256, uint256 } from 'starknet';
import {
  safeWithL1AvatarExecutionStrategySetup,
  increaseEthBlockchainTime,
  extractMessagePayload,
} from './utils';

dotenv.config();

const eth_network: string = (network.config as HttpNetworkConfig).url;
const account_address = process.env.ADDRESS || '';
const account_pk = process.env.PK || '';

describe('L1 Avatar Execution', function () {
  this.timeout(1000000);

  let signer: ethers.Wallet;
  let safe: ethers.Contract;
  let mockStarknetMessaging: ethers.Contract;
  let l1AvatarExecutionStrategy: ethers.Contract;

  let account: starknet.starknetAccount;
  let starkTxAuthenticator: starknet.StarknetContract;
  let vanillaVotingStrategy: starknet.StarknetContract;
  let vanillaProposalValidationStrategy: starknet.StarknetContract;
  let space: starknet.StarknetContract;
  let ethRelayer: starknet.StarknetContract;

  before(async function () {
    const signers = await ethers.getSigners();
    signer = signers[0];

    account = await starknet.OpenZeppelinAccount.getAccountFromAddress(account_address, account_pk);

    const starkTxAuthenticatorFactory = await starknet.getContractFactory(
      'sx_StarkTxAuthenticator',
    );
    const vanillaVotingStrategyFactory = await starknet.getContractFactory(
      'sx_VanillaVotingStrategy',
    );
    const vanillaProposalValidationStrategyFactory = await starknet.getContractFactory(
      'sx_VanillaProposalValidationStrategy',
    );
    const ethRelayerFactory = await starknet.getContractFactory('sx_EthRelayerExecutionStrategy');
    const spaceFactory = await starknet.getContractFactory('sx_Space');

    try {
      // If the contracts are already declared, this will be skipped
      await account.declare(starkTxAuthenticatorFactory);
      await account.declare(vanillaVotingStrategyFactory);
      await account.declare(vanillaProposalValidationStrategyFactory);
      await account.declare(ethRelayerFactory);
      await account.declare(spaceFactory);
    } catch {}

    starkTxAuthenticator = await account.deploy(starkTxAuthenticatorFactory);
    vanillaVotingStrategy = await account.deploy(vanillaVotingStrategyFactory);
    vanillaProposalValidationStrategy = await account.deploy(
      vanillaProposalValidationStrategyFactory,
    );
    ethRelayer = await account.deploy(ethRelayerFactory);
    space = await account.deploy(spaceFactory);

    // Initializing the space
    const initializeCalldata = CallData.compile({
      _owner: 1,
      _max_voting_duration: 10,
      _min_voting_duration: 10,
      _voting_delay: 0,
      _proposal_validation_strategy: {
        address: vanillaProposalValidationStrategy.address,
        params: [],
      },
      _proposal_validation_strategy_metadata_URI: [],
      _voting_strategies: [{ address: vanillaVotingStrategy.address, params: [] }],
      _voting_strategies_metadata_URI: [],
      _authenticators: [starkTxAuthenticator.address],
      _metadata_URI: [],
      _dao_URI: [],
    });

    await account.invoke(space, 'initialize', initializeCalldata, { rawInput: true });

    const quorum = 1;

    const MockStarknetMessaging = await ethers.getContractFactory('MockStarknetMessaging', signer);
    const messageCancellationDelay = 5 * 60; // seconds
    mockStarknetMessaging = await MockStarknetMessaging.deploy(messageCancellationDelay);

    ({ l1AvatarExecutionStrategy, safe } = await safeWithL1AvatarExecutionStrategySetup(
      signer,
      mockStarknetMessaging.address,
      space.address,
      ethRelayer.address,
      quorum,
    ));

    // Dumping the Starknet state so it can be loaded at the same point for each test
    await starknet.devnet.dump('dump.pkl');
  }, 10000000);

  it('should execute a proposal via the Avatar Execution Strategy connected to a Safe', async function () {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const proposalTx = {
      to: signer.address,
      value: 0,
      data: '0x11',
      operation: 0,
      salt: 1,
    };

    const abiCoder = new ethers.utils.AbiCoder();
    const executionHash = ethers.utils.keccak256(
      abiCoder.encode(
        ['tuple(address to, uint256 value, bytes data, uint8 operation, uint256 salt)[]'],
        [[proposalTx]],
      ),
    );
    // Represent the execution hash as a Cairo Uint256
    const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

    const executionPayload = [
      l1AvatarExecutionStrategy.address,
      executionHashUint256.low,
      executionHashUint256.high,
    ];

    // Propose
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_propose',
      CallData.compile({
        space: space.address,
        author: account.address,
        executionStrategy: {
          address: ethRelayer.address,
          params: executionPayload,
        },
        userProposalValidationParams: [],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    // Vote
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_vote',
      CallData.compile({
        space: space.address,
        voter: account.address,
        proposalId: { low: '0x1', high: '0x0' },
        choice: '0x1',
        userVotingStrategies: [{ index: '0x0', params: [] }],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    // Advance time so that the maxVotingTimestamp is exceeded
    await starknet.devnet.increaseTime(10);
    await increaseEthBlockchainTime(eth_network, 10);

    // Execute
    await account.invoke(
      space,
      'execute',
      CallData.compile({
        proposalId: { low: '0x1', high: '0x0' },
        executionPayload: executionPayload,
      }),
      { rawInput: true },
    );

    // Propagating message to L1
    const flushL2Response = await starknet.devnet.flush();
    const message_payload = flushL2Response.consumed_messages.from_l2[0].payload;

    // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
    const [proposal, forVotes, againstVotes, abstainVotes] = extractMessagePayload(message_payload);

    await l1AvatarExecutionStrategy.execute(
      space.address,
      proposal,
      forVotes,
      againstVotes,
      abstainVotes,
      executionHash,
      [proposalTx],
    );
  }, 10000000);

  it('should execute a proposal with multiple txs via the Avatar Execution Strategy connected to a Safe', async function () {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const proposalTx = {
      to: signer.address,
      value: 0,
      data: '0x11',
      operation: 0,
      salt: 1,
    };

    const proposalTx2 = {
      to: signer.address,
      value: 0,
      data: '0x22',
      operation: 0,
      salt: 1,
    };

    const abiCoder = new ethers.utils.AbiCoder();
    const executionHash = ethers.utils.keccak256(
      abiCoder.encode(
        ['tuple(address to, uint256 value, bytes data, uint8 operation, uint256 salt)[]'],
        [[proposalTx, proposalTx2]],
      ),
    );
    // Represent the execution hash as a Cairo Uint256
    const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

    const executionPayload = [
      l1AvatarExecutionStrategy.address,
      executionHashUint256.low,
      executionHashUint256.high,
    ];

    // Propose
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_propose',
      CallData.compile({
        space: space.address,
        author: account.address,
        executionStrategy: {
          address: ethRelayer.address,
          params: executionPayload,
        },
        userProposalValidationParams: [],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    // Vote
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_vote',
      CallData.compile({
        space: space.address,
        voter: account.address,
        proposalId: { low: '0x1', high: '0x0' },
        choice: '0x1',
        userVotingStrategies: [{ index: '0x0', params: [] }],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    // Advance time so that the maxVotingTimestamp is exceeded
    await starknet.devnet.increaseTime(10);
    await increaseEthBlockchainTime(eth_network, 10);

    // Execute
    await account.invoke(
      space,
      'execute',
      CallData.compile({
        proposalId: { low: '0x1', high: '0x0' },
        executionPayload: executionPayload,
      }),
      { rawInput: true },
    );

    // Propagating message to L1
    const flushL2Response = await starknet.devnet.flush();
    const message_payload = flushL2Response.consumed_messages.from_l2[0].payload;

    // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
    const [proposal, forVotes, againstVotes, abstainVotes] = extractMessagePayload(message_payload);

    await l1AvatarExecutionStrategy.execute(
      space.address,
      proposal,
      forVotes,
      againstVotes,
      abstainVotes,
      executionHash,
      [proposalTx, proposalTx2],
    );
  }, 10000000);

  it('should revert execution if an invalid payload is sent to L1', async function () {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const proposalTx = {
      to: signer.address,
      value: 0,
      data: '0x22',
      operation: 0,
      salt: 1,
    };

    const abiCoder = new ethers.utils.AbiCoder();
    const executionHash = ethers.utils.keccak256(
      abiCoder.encode(
        ['tuple(address to, uint256 value, bytes data, uint8 operation, uint256 salt)[]'],
        [[proposalTx]],
      ),
    );
    // Represent the execution hash as a Cairo Uint256
    const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

    const executionPayload = [
      l1AvatarExecutionStrategy.address,
      executionHashUint256.low,
      executionHashUint256.high,
    ];

    // Propose
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_propose',
      CallData.compile({
        space: space.address,
        author: account.address,
        executionStrategy: {
          address: ethRelayer.address,
          params: executionPayload,
        },
        userProposalValidationParams: [],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    // Vote
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_vote',
      CallData.compile({
        space: space.address,
        voter: account.address,
        proposalId: { low: '0x1', high: '0x0' },
        choice: '0x1',
        userVotingStrategies: [{ index: '0x0', params: [] }],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    // Advance time so that the maxVotingTimestamp is exceeded
    await starknet.devnet.increaseTime(10);
    await increaseEthBlockchainTime(eth_network, 10);

    // Execute
    await account.invoke(
      space,
      'execute',
      CallData.compile({
        proposalId: { low: '0x1', high: '0x0' },
        executionPayload: executionPayload,
      }),
      { rawInput: true },
    );

    // Propagating message to L1
    const flushL2Response = await starknet.devnet.flush();
    const message_payload = flushL2Response.consumed_messages.from_l2[0].payload;
    // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
    const [proposal, forVotes, againstVotes, abstainVotes] = extractMessagePayload(message_payload);

    // Incorrect forVotes value was supplied
    await expect(
      l1AvatarExecutionStrategy.execute(
        space.address,
        proposal,
        10,
        againstVotes,
        abstainVotes,
        executionHash,
        [proposalTx],
      ),
    ).to.be.revertedWith('INVALID_MESSAGE_TO_CONSUME');
  }, 10000000);

  it('should revert execution if an invalid proposal tx is sent to the execution strategy', async function () {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const proposalTx = {
      to: signer.address,
      value: 0,
      data: '0x22',
      operation: 0,
      salt: 1,
    };

    const abiCoder = new ethers.utils.AbiCoder();
    const executionHash = ethers.utils.keccak256(
      abiCoder.encode(
        ['tuple(address to, uint256 value, bytes data, uint8 operation, uint256 salt)[]'],
        [[proposalTx]],
      ),
    );
    // Represent the execution hash as a Cairo Uint256
    const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

    const executionPayload = [
      l1AvatarExecutionStrategy.address,
      executionHashUint256.low,
      executionHashUint256.high,
    ];

    // Propose
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_propose',
      CallData.compile({
        space: space.address,
        author: account.address,
        executionStrategy: {
          address: ethRelayer.address,
          params: executionPayload,
        },
        userProposalValidationParams: [],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    // Vote
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_vote',
      CallData.compile({
        space: space.address,
        voter: account.address,
        proposalId: { low: '0x1', high: '0x0' },
        choice: '0x1',
        userVotingStrategies: [{ index: '0x0', params: [] }],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    // Advance time so that the maxVotingTimestamp is exceeded
    await starknet.devnet.increaseTime(10);
    await increaseEthBlockchainTime(eth_network, 10);

    // Execute
    await account.invoke(
      space,
      'execute',
      CallData.compile({
        proposalId: { low: '0x1', high: '0x0' },
        executionPayload: executionPayload,
      }),
      { rawInput: true },
    );

    // Propagating message to L1
    const flushL2Response = await starknet.devnet.flush();
    const message_payload = flushL2Response.consumed_messages.from_l2[0].payload;
    // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
    const [proposal, forVotes, againstVotes, abstainVotes] = extractMessagePayload(message_payload);


    const fakeProposalTx = {
      to: signer.address,
      value: 10,
      data: '0x22',
      operation: 0,
      salt: 1,
    };

    // Incorrect forVotes value was supplied
    await expect(
      l1AvatarExecutionStrategy.execute(
        space.address,
        proposal,
        forVotes,
        againstVotes,
        abstainVotes,
        executionHash,
        [fakeProposalTx],
      ),
    ).to.be.revertedWith('InvalidPayload');
  }, 10000000);

  it('should revert execution if quorum is not met (abstain votes only)', async function () {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const proposalTx = {
      to: signer.address,
      value: 0,
      data: '0x22',
      operation: 0,
      salt: 1,
    };

    const abiCoder = new ethers.utils.AbiCoder();
    const executionHash = ethers.utils.keccak256(
      abiCoder.encode(
        ['tuple(address to, uint256 value, bytes data, uint8 operation, uint256 salt)[]'],
        [[proposalTx]],
      ),
    );
    // Represent the execution hash as a Cairo Uint256
    const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

    const executionPayload = [
      l1AvatarExecutionStrategy.address,
      executionHashUint256.low,
      executionHashUint256.high,
    ];

    // Propose
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_propose',
      CallData.compile({
        space: space.address,
        author: account.address,
        executionStrategy: {
          address: ethRelayer.address,
          params: executionPayload,
        },
        userProposalValidationParams: [],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    // Vote
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_vote',
      CallData.compile({
        space: space.address,
        voter: account.address,
        proposalId: { low: '0x1', high: '0x0' },
        choice: '0x2',
        userVotingStrategies: [{ index: '0x0', params: [] }],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    // Advance time so that the maxVotingTimestamp is exceeded
    await starknet.devnet.increaseTime(10);
    await increaseEthBlockchainTime(eth_network, 10);

    // Execute
    await account.invoke(
      space,
      'execute',
      CallData.compile({
        proposalId: { low: '0x1', high: '0x0' },
        executionPayload: executionPayload,
      }),
      { rawInput: true },
    );

    // Propagating message to L1
    const flushL2Response = await starknet.devnet.flush();
    const message_payload = flushL2Response.consumed_messages.from_l2[0].payload;
    // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
    const [proposal, forVotes, againstVotes, abstainVotes] = extractMessagePayload(message_payload);

    // For some reason CI fails with revertedWith('InvalidProposalStatus') but works locally.
    await expect(
      l1AvatarExecutionStrategy.execute(
        space.address,
        proposal,
        forVotes,
        againstVotes,
        abstainVotes,
        executionHash,
        [proposalTx],
      ),
    ).to.be.reverted;
  }, 10000000);

  it('should revert execution if quorum is not met (against votes only)', async function () {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const proposalTx = {
      to: signer.address,
      value: 0,
      data: '0x22',
      operation: 0,
      salt: 1,
    };

    const abiCoder = new ethers.utils.AbiCoder();
    const executionHash = ethers.utils.keccak256(
      abiCoder.encode(
        ['tuple(address to, uint256 value, bytes data, uint8 operation, uint256 salt)[]'],
        [[proposalTx]],
      ),
    );
    // Represent the execution hash as a Cairo Uint256
    const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

    const executionPayload = [
      l1AvatarExecutionStrategy.address,
      executionHashUint256.low,
      executionHashUint256.high,
    ];

    // Propose
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_propose',
      CallData.compile({
        space: space.address,
        author: account.address,
        executionStrategy: {
          address: ethRelayer.address,
          params: executionPayload,
        },
        userProposalValidationParams: [],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    // Vote
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_vote',
      CallData.compile({
        space: space.address,
        voter: account.address,
        proposalId: { low: '0x1', high: '0x0' },
        choice: '0x0',
        userVotingStrategies: [{ index: '0x0', params: [] }],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    // Advance time so that the maxVotingTimestamp is exceeded
    await starknet.devnet.increaseTime(10);
    await increaseEthBlockchainTime(eth_network, 10);

    // Execute
    await account.invoke(
      space,
      'execute',
      CallData.compile({
        proposalId: { low: '0x1', high: '0x0' },
        executionPayload: executionPayload,
      }),
      { rawInput: true },
    );

    // Propagating message to L1
    const flushL2Response = await starknet.devnet.flush();
    const message_payload = flushL2Response.consumed_messages.from_l2[0].payload;
    // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
    const [proposal, forVotes, againstVotes, abstainVotes] = extractMessagePayload(message_payload);

    // For some reason CI fails with revertedWith('InvalidProposalStatus') but works locally.
    await expect(
      l1AvatarExecutionStrategy.execute(
        space.address,
        proposal,
        forVotes,
        againstVotes,
        abstainVotes,
        executionHash,
        [proposalTx],
      ),
    ).to.be.reverted;
  }, 10000000);

  it('should revert execution if quorum is not met (no votes)', async function () {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);
    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const proposalTx = {
      to: signer.address,
      value: 0,
      data: '0x22',
      operation: 0,
      salt: 1,
    };

    const abiCoder = new ethers.utils.AbiCoder();
    const executionHash = ethers.utils.keccak256(
      abiCoder.encode(
        ['tuple(address to, uint256 value, bytes data, uint8 operation, uint256 salt)[]'],
        [[proposalTx]],
      ),
    );
    // Represent the execution hash as a Cairo Uint256
    const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

    const executionPayload = [
      l1AvatarExecutionStrategy.address,
      executionHashUint256.low,
      executionHashUint256.high,
    ];

    // Propose
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_propose',
      CallData.compile({
        space: space.address,
        author: account.address,
        executionStrategy: {
          address: ethRelayer.address,
          params: executionPayload,
        },
        userProposalValidationParams: [],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    // No Vote Cast

    // Advance time so that the maxVotingTimestamp is exceeded
    await starknet.devnet.increaseTime(10);
    await increaseEthBlockchainTime(eth_network, 10);

    // Execute
    await account.invoke(
      space,
      'execute',
      CallData.compile({
        proposalId: { low: '0x1', high: '0x0' },
        executionPayload: executionPayload,
      }),
      { rawInput: true },
    );

    // Propagating message to L1
    const flushL2Response = await starknet.devnet.flush();
    const message_payload = flushL2Response.consumed_messages.from_l2[0].payload;
    // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
    const [proposal, forVotes, againstVotes, abstainVotes] = extractMessagePayload(message_payload);

    // For some reason CI fails with revertedWith('InvalidProposalStatus') but works locally.
    await expect(
      l1AvatarExecutionStrategy.execute(
        space.address,
        proposal,
        forVotes,
        againstVotes,
        abstainVotes,
        executionHash,
        [proposalTx],
      ),
    ).to.be.reverted;
  }, 10000000);

  it('should revert execution if voting period is not exceeded', async function () {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);

    await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

    const proposalTx = {
      to: signer.address,
      value: 0,
      data: '0x22',
      operation: 0,
      salt: 1,
    };

    const abiCoder = new ethers.utils.AbiCoder();
    const executionHash = ethers.utils.keccak256(
      abiCoder.encode(
        ['tuple(address to, uint256 value, bytes data, uint8 operation, uint256 salt)[]'],
        [[proposalTx]],
      ),
    );
    // Represent the execution hash as a Cairo Uint256
    const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

    const executionPayload = [
      l1AvatarExecutionStrategy.address,
      executionHashUint256.low,
      executionHashUint256.high,
    ];

    // Propose
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_propose',
      CallData.compile({
        space: space.address,
        author: account.address,
        executionStrategy: {
          address: ethRelayer.address,
          params: executionPayload,
        },
        userProposalValidationParams: [],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    // Vote
    await account.invoke(
      starkTxAuthenticator,
      'authenticate_vote',
      CallData.compile({
        space: space.address,
        voter: account.address,
        proposalId: { low: '0x1', high: '0x0' },
        choice: '0x1',
        userVotingStrategies: [{ index: '0x0', params: [] }],
        metadataURI: [],
      }),
      { rawInput: true },
    );

    try {
      // Execute before maxVotingTimestamp is exceeded
      await account.invoke(
        space,
        'execute',
        CallData.compile({
          proposalId: { low: '0x1', high: '0x0' },
          executionPayload: executionPayload,
        }),
        { rawInput: true },
      );
    } catch (err: any) {
      // 'Before max end timestamp' error message
      expect(err.message).to.contain('0x4265666f7265206d617820656e642074696d657374616d70');
    }
  }, 10000000);
});
