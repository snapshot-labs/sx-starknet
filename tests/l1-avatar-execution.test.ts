import dotenv from 'dotenv';
import { expect } from 'chai';
import { HttpNetworkConfig } from 'hardhat/types';
import { RpcProvider as StarknetRpcProvider, Contract as StarknetContract, Account as StarknetAccount, CallData, Uint256, uint256, CairoCustomEnum } from 'starknet';
import { Contract as EthContract } from 'ethers';
import { Devnet as StarknetDevnet, DevnetProvider as StarknetDevnetProvider } from 'starknet-devnet';
import { ethers, config } from 'hardhat';

import {
  safeWithL1AvatarExecutionStrategySetup,
  increaseEthBlockchainTime,
  extractMessagePayload,
} from './utils';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { getCompiledCode } from './utils';
import { AbiCoder, keccak256 } from 'ethers';

dotenv.config();

const eth_network: string = (config.networks.ethereumLocal as HttpNetworkConfig).url;
const account_address = process.env.ADDRESS || '';
const account_pk = process.env.PK || '';

describe('L1 Avatar Execution', function () {
  this.timeout(1000000);

  let signer: HardhatEthersSigner;
  let safe: EthContract;
  // let mockStarknetMessaging: EthContract;
  let mockMessagingContractAddress: string;
  let l1AvatarExecutionStrategy: EthContract;

  let account: StarknetAccount;
  let starkTxAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaProposalValidationStrategy: StarknetContract;
  let space: StarknetContract;
  let ethRelayer: StarknetContract;

  let starknetDevnet: StarknetDevnet;
  let starknetDevnetProvider: StarknetDevnetProvider;
  let provider: StarknetRpcProvider;

  before(async function () {
    console.log('account address:', account_address, 'account pk:', account_pk);

    const devnetConfig = {
      args: ["--seed", "42", "--lite-mode", "--dump-on", "exit", "--dump-path", "./dump.pkl", "--host", "127.0.0.1", "--port", "5050"],
    };
    console.log("Spawning devnet...");
    starknetDevnet = await StarknetDevnet.spawnInstalled(devnetConfig); // TODO: should be a new rather than spawninstalled
    starknetDevnetProvider = new StarknetDevnetProvider();

    console.log("Loading L1 Messaging Contract");
    const messagingLoadResponse = await starknetDevnetProvider.postman.loadL1MessagingContract(eth_network);
    mockMessagingContractAddress = messagingLoadResponse.messaging_contract_address;
    console.log("mock messaging contract", mockMessagingContractAddress);

    provider = new StarknetRpcProvider({ nodeUrl: starknetDevnet.provider.url });

    // Account used for deployments
    account = new StarknetAccount(provider, account_address, account_pk);

    // Deploy the Stark Sig Authenticator
    console.log("Deploying Stark Tx Authenticator...");
    const { sierraCode: auth_sierra, casmCode: auth_casm } = await getCompiledCode('sx_StarkTxAuthenticator');
    const auth_response = await account.declareAndDeploy({ contract: auth_sierra, casm: auth_casm });
    starkTxAuthenticator = new StarknetContract(auth_sierra.abi, auth_response.deploy.contract_address, provider);
    console.log("Stark Eth Authenticator: ", starkTxAuthenticator.address);

    // Deploy the Vanilla Voting strategy
    console.log("Deploying Voting Strategy...");
    const { sierraCode: voting_sierra, casmCode: voting_casm } = await getCompiledCode('sx_VanillaVotingStrategy');
    const voting_response = await account.declareAndDeploy({ contract: voting_sierra, casm: voting_casm });
    vanillaVotingStrategy = new StarknetContract(voting_sierra.abi, voting_response.deploy.contract_address, provider);
    console.log("Vanilla Voting Strategy: ", vanillaVotingStrategy.address);

    // Deploy the Vanilla Proposal Validation strategy
    console.log("Deploying Validation Strategy...");
    const { sierraCode: proposal_sierra, casmCode: proposal_casm } = await getCompiledCode('sx_VanillaProposalValidationStrategy');
    const proposal_response = await account.declareAndDeploy({ contract: proposal_sierra, casm: proposal_casm });
    vanillaProposalValidationStrategy = new StarknetContract(proposal_sierra.abi, proposal_response.deploy.contract_address, provider);
    console.log("Vanilla Proposal Validation Strategy: ", vanillaProposalValidationStrategy.address);

    // Deploy the EthRelayer
    console.log("Deploying Eth Relayer...");
    const { sierraCode: relayer_sierra, casmCode: relayer_casm } = await getCompiledCode('sx_EthRelayerExecutionStrategy');
    const relayer_response = await account.declareAndDeploy({ contract: relayer_sierra, casm: relayer_casm });
    ethRelayer = new StarknetContract(relayer_sierra.abi, relayer_response.deploy.contract_address, provider);
    console.log("Eth Relayer: ", ethRelayer.address);

    // Deploy the Space
    console.log("Deploying Space...");
    const { sierraCode: space_sierra, casmCode: space_casm } = await getCompiledCode('sx_Space');
    const space_response = await account.declareAndDeploy({ contract: space_sierra, casm: space_casm });
    space = new StarknetContract(space_sierra.abi, space_response.deploy.contract_address, provider);
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
    const _authenticators = [starkTxAuthenticator.address];
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
    console.log("Space initialized");

    // Dumping the Starknet state so it can be loaded at the same point for each test
    console.log("Dumping state...");
    await starknetDevnet.provider.dump('dump.pkl');
    console.log("State dumped");

    // Ethereum setup
    const signers = await ethers.getSigners();
    signer = signers[0];
    const quorum = 1;

    ({ l1AvatarExecutionStrategy, safe } = await safeWithL1AvatarExecutionStrategySetup(
      signer,
      mockMessagingContractAddress,
      space.address,
      ethRelayer.address,
      quorum,
    ));
  });

  it('should execute a proposal via the Avatar Execution Strategy connected to a Safe', async function () {
    await starknetDevnet.provider.restart();
    await starknetDevnet.provider.load('./dump.pkl');
    await starknetDevnetProvider.postman.loadL1MessagingContract(eth_network, mockMessagingContractAddress);

    const proposalTx = {
      to: signer.address,
      value: 0,
      data: '0x11',
      operation: 0,
    };

    const abiCoder = new AbiCoder();
    const executionHash = keccak256(
      abiCoder.encode(
        ['tuple(address to, uint256 value, bytes data, uint8 operation)[]'],
        [[proposalTx]],
      ),
    );
    // Represent the execution hash as a Cairo Uint256
    const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

    const executionPayload = [
      await l1AvatarExecutionStrategy.getAddress(),
      executionHashUint256.low,
      executionHashUint256.high,
    ];
    const proposalId = { low: '0x1', high: '0x0' };

    starkTxAuthenticator.connect(account);

    console.log("Authenticating propose...");
    const proposeRes = await starkTxAuthenticator.authenticate_propose(space.address, account.address, [], { address: ethRelayer.address, params: executionPayload }, []);
    await provider.waitForTransaction(proposeRes.transaction_hash);
    console.log("Propose authenticated");

    await starknetDevnet.provider.increaseTime(101);
    await increaseEthBlockchainTime(eth_network, 101);

    console.log("Authenticating vote...");
    const choice = new CairoCustomEnum({ For: {} });
    const voteRes = await starkTxAuthenticator.authenticate_vote(space.address, account.address, proposalId, choice, [{ index: '0x0', params: [] }], []);
    await provider.waitForTransaction(voteRes.transaction_hash);
    console.log("Vote authenticated");

    // Advance time so that the maxVotingTimestamp is exceeded
    await starknetDevnet.provider.increaseTime(200);
    await increaseEthBlockchainTime(eth_network, 200);

    // Execute
    console.log("Executing proposal...");
    const executeRes = await space.execute(proposalId, executionPayload);
    await provider.waitForTransaction(executeRes.transaction_hash);
    console.log("Proposal executed");

    // Propagating message to L1
    console.log("Flushing");
    const flushL2Response = await starknetDevnetProvider.postman.flush();
    console.log("response to l1: ", flushL2Response);
    const message_payload = flushL2Response.messages_to_l1[0].payload;

    // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
    const [proposalId_, proposal, votes] = extractMessagePayload(message_payload);

    console.log("Executing on L1");
    await expect(l1AvatarExecutionStrategy.execute(
      space.address,
      proposalId_,
      proposal,
      votes,
      executionHash,
      [proposalTx],
    )).to.emit(l1AvatarExecutionStrategy, 'ProposalExecuted').withArgs(space.address.toString(), proposalId_);
    console.log("Executed on L1!");
  });

  // it('should execute a proposal with multiple txs via the Avatar Execution Strategy connected to a Safe', async function () {
  //   await starknet.devnet.restart();
  //   await starknet.devnet.load('./dump.pkl');
  //   await starknet.devnet.increaseTime(10);
  //   await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

  //   const proposalTx = {
  //     to: signer.address,
  //     value: 0,
  //     data: '0x11',
  //     operation: 0,
  //   };

  //   const proposalTx2 = {
  //     to: signer.address,
  //     value: 0,
  //     data: '0x22',
  //     operation: 0,
  //     salt: 1,
  //   };

  //   const abiCoder = new ethers.utils.AbiCoder();
  //   const executionHash = ethers.utils.keccak256(
  //     abiCoder.encode(
  //       ['tuple(address to, uint256 value, bytes data, uint8 operation)[]'],
  //       [[proposalTx, proposalTx2]],
  //     ),
  //   );
  //   // Represent the execution hash as a Cairo Uint256
  //   const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

  //   const executionPayload = [
  //     l1AvatarExecutionStrategy.address,
  //     executionHashUint256.low,
  //     executionHashUint256.high,
  //   ];

  //   // Propose
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_propose',
  //     CallData.compile({
  //       space: space.address,
  //       author: account.address,
  //       metadataURI: [],
  //       executionStrategy: {
  //         address: ethRelayer.address,
  //         params: executionPayload,
  //       },
  //       userProposalValidationParams: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   // Vote
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_vote',
  //     CallData.compile({
  //       space: space.address,
  //       voter: account.address,
  //       proposalId: { low: '0x1', high: '0x0' },
  //       choice: '0x1',
  //       userVotingStrategies: [{ index: '0x0', params: [] }],
  //       metadataURI: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   // Advance time so that the maxVotingTimestamp is exceeded
  //   await starknet.devnet.increaseTime(10);
  //   await increaseEthBlockchainTime(eth_network, 10);

  //   // Execute
  //   await account.invoke(
  //     space,
  //     'execute',
  //     CallData.compile({
  //       proposalId: { low: '0x1', high: '0x0' },
  //       executionPayload: executionPayload,
  //     }),
  //     { rawInput: true },
  //   );

  //   // Propagating message to L1
  //   const flushL2Response = await starknet.devnet.flush();
  //   const message_payload = flushL2Response.consumed_messages.from_l2[0].payload;

  //   // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
  //   const [proposalId, proposal, votes] = extractMessagePayload(message_payload);

  //   await l1AvatarExecutionStrategy.execute(
  //     space.address,
  //     proposalId,
  //     proposal,
  //     votes,
  //     executionHash,
  //     [proposalTx, proposalTx2],
  //   );
  // }, 10000000);

  // it('should revert if the space is not whitelisted in the Avatar execution strategy', async function () {
  //   await starknet.devnet.restart();
  //   await starknet.devnet.load('./dump.pkl');
  //   await starknet.devnet.increaseTime(10);
  //   await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

  //   // Disabling the space in the execution strategy
  //   await l1AvatarExecutionStrategy.disableSpace(space.address);

  //   const proposalTx = {
  //     to: signer.address,
  //     value: 0,
  //     data: '0x11',
  //     operation: 0,
  //   };

  //   const abiCoder = new ethers.utils.AbiCoder();
  //   const executionHash = ethers.utils.keccak256(
  //     abiCoder.encode(
  //       ['tuple(address to, uint256 value, bytes data, uint8 operation)[]'],
  //       [[proposalTx]],
  //     ),
  //   );
  //   // Represent the execution hash as a Cairo Uint256
  //   const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

  //   const executionPayload = [
  //     l1AvatarExecutionStrategy.address,
  //     executionHashUint256.low,
  //     executionHashUint256.high,
  //   ];

  //   // Propose
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_propose',
  //     CallData.compile({
  //       space: space.address,
  //       author: account.address,
  //       metadataURI: [],
  //       executionStrategy: {
  //         address: ethRelayer.address,
  //         params: executionPayload,
  //       },
  //       userProposalValidationParams: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   // Vote
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_vote',
  //     CallData.compile({
  //       space: space.address,
  //       voter: account.address,
  //       proposalId: { low: '0x1', high: '0x0' },
  //       choice: '0x1',
  //       userVotingStrategies: [{ index: '0x0', params: [] }],
  //       metadataURI: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   // Advance time so that the maxVotingTimestamp is exceeded
  //   await starknet.devnet.increaseTime(10);
  //   await increaseEthBlockchainTime(eth_network, 10);

  //   // Execute
  //   await account.invoke(
  //     space,
  //     'execute',
  //     CallData.compile({
  //       proposalId: { low: '0x1', high: '0x0' },
  //       executionPayload: executionPayload,
  //     }),
  //     { rawInput: true },
  //   );

  //   // Propagating message to L1
  //   const flushL2Response = await starknet.devnet.flush();
  //   const message_payload = flushL2Response.consumed_messages.from_l2[0].payload;

  //   // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
  //   const [proposalId, proposal, votes] = extractMessagePayload(message_payload);

  //   await expect(
  //     l1AvatarExecutionStrategy.execute(
  //       space.address,
  //       proposalId,
  //       proposal,
  //       votes,
  //       executionHash,
  //       [proposalTx],
  //     ),
  //   ).to.be.reverted;

  //   // Re-enabling the space in the execution strategy
  //   await l1AvatarExecutionStrategy.enableSpace(space.address);
  // }, 10000000);

  // it('should revert execution if an invalid payload is sent to L1', async function () {
  //   await starknet.devnet.restart();
  //   await starknet.devnet.load('./dump.pkl');
  //   await starknet.devnet.increaseTime(10);
  //   await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

  //   const proposalTx = {
  //     to: signer.address,
  //     value: 0,
  //     data: '0x22',
  //     operation: 0,
  //   };

  //   const abiCoder = new ethers.utils.AbiCoder();
  //   const executionHash = ethers.utils.keccak256(
  //     abiCoder.encode(
  //       ['tuple(address to, uint256 value, bytes data, uint8 operation)[]'],
  //       [[proposalTx]],
  //     ),
  //   );
  //   // Represent the execution hash as a Cairo Uint256
  //   const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

  //   const executionPayload = [
  //     l1AvatarExecutionStrategy.address,
  //     executionHashUint256.low,
  //     executionHashUint256.high,
  //   ];

  //   // Propose
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_propose',
  //     CallData.compile({
  //       space: space.address,
  //       author: account.address,
  //       metadataURI: [],
  //       executionStrategy: {
  //         address: ethRelayer.address,
  //         params: executionPayload,
  //       },
  //       userProposalValidationParams: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   // Vote
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_vote',
  //     CallData.compile({
  //       space: space.address,
  //       voter: account.address,
  //       proposalId: { low: '0x1', high: '0x0' },
  //       choice: '0x1',
  //       userVotingStrategies: [{ index: '0x0', params: [] }],
  //       metadataURI: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   // Advance time so that the maxVotingTimestamp is exceeded
  //   await starknet.devnet.increaseTime(10);
  //   await increaseEthBlockchainTime(eth_network, 10);

  //   // Execute
  //   await account.invoke(
  //     space,
  //     'execute',
  //     CallData.compile({
  //       proposalId: { low: '0x1', high: '0x0' },
  //       executionPayload: executionPayload,
  //     }),
  //     { rawInput: true },
  //   );

  //   // Propagating message to L1
  //   const flushL2Response = await starknet.devnet.flush();
  //   const message_payload = flushL2Response.consumed_messages.from_l2[0].payload;
  //   // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
  //   const [proposalId, proposal, votes] = extractMessagePayload(message_payload);

  //   // Manually set an incorrect votesFor value
  //   votes.votesFor = 10;

  //   await expect(
  //     l1AvatarExecutionStrategy.execute(
  //       space.address,
  //       proposalId,
  //       proposal,
  //       votes,
  //       executionHash,
  //       [proposalTx],
  //     ),
  //   ).to.be.revertedWith('INVALID_MESSAGE_TO_CONSUME');
  // }, 10000000);

  // it('should revert execution if an invalid proposal tx is sent to the execution strategy', async function () {
  //   await starknet.devnet.restart();
  //   await starknet.devnet.load('./dump.pkl');
  //   await starknet.devnet.increaseTime(10);
  //   await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

  //   const proposalTx = {
  //     to: signer.address,
  //     value: 0,
  //     data: '0x22',
  //     operation: 0,
  //   };

  //   const abiCoder = new ethers.utils.AbiCoder();
  //   const executionHash = ethers.utils.keccak256(
  //     abiCoder.encode(
  //       ['tuple(address to, uint256 value, bytes data, uint8 operation)[]'],
  //       [[proposalTx]],
  //     ),
  //   );
  //   // Represent the execution hash as a Cairo Uint256
  //   const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

  //   const executionPayload = [
  //     l1AvatarExecutionStrategy.address,
  //     executionHashUint256.low,
  //     executionHashUint256.high,
  //   ];

  //   // Propose
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_propose',
  //     CallData.compile({
  //       space: space.address,
  //       author: account.address,
  //       metadataURI: [],
  //       executionStrategy: {
  //         address: ethRelayer.address,
  //         params: executionPayload,
  //       },
  //       userProposalValidationParams: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   // Vote
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_vote',
  //     CallData.compile({
  //       space: space.address,
  //       voter: account.address,
  //       proposalId: { low: '0x1', high: '0x0' },
  //       choice: '0x1',
  //       userVotingStrategies: [{ index: '0x0', params: [] }],
  //       metadataURI: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   // Advance time so that the maxVotingTimestamp is exceeded
  //   await starknet.devnet.increaseTime(10);
  //   await increaseEthBlockchainTime(eth_network, 10);

  //   // Execute
  //   await account.invoke(
  //     space,
  //     'execute',
  //     CallData.compile({
  //       proposalId: { low: '0x1', high: '0x0' },
  //       executionPayload: executionPayload,
  //     }),
  //     { rawInput: true },
  //   );

  //   // Propagating message to L1
  //   const flushL2Response = await starknet.devnet.flush();
  //   const message_payload = flushL2Response.consumed_messages.from_l2[0].payload;
  //   // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
  //   const [proposalId, proposal, votes] = extractMessagePayload(message_payload);

  //   const fakeProposalTx = {
  //     to: signer.address,
  //     value: 10,
  //     data: '0x22',
  //     operation: 0,
  //     salt: 1,
  //   };

  //   // Sending fake proposal tx to the execution strategy
  //   await expect(
  //     l1AvatarExecutionStrategy.execute(
  //       space.address,
  //       proposalId,
  //       proposal,
  //       votes,
  //       executionHash,
  //       [fakeProposalTx],
  //     ),
  //   ).to.be.reverted;
  // }, 10000000);

  // it('should revert execution if quorum is not met (abstain votes only)', async function () {
  //   await starknet.devnet.restart();
  //   await starknet.devnet.load('./dump.pkl');
  //   await starknet.devnet.increaseTime(10);
  //   await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

  //   const proposalTx = {
  //     to: signer.address,
  //     value: 0,
  //     data: '0x22',
  //     operation: 0,
  //   };

  //   const abiCoder = new ethers.utils.AbiCoder();
  //   const executionHash = ethers.utils.keccak256(
  //     abiCoder.encode(
  //       ['tuple(address to, uint256 value, bytes data, uint8 operation)[]'],
  //       [[proposalTx]],
  //     ),
  //   );
  //   // Represent the execution hash as a Cairo Uint256
  //   const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

  //   const executionPayload = [
  //     l1AvatarExecutionStrategy.address,
  //     executionHashUint256.low,
  //     executionHashUint256.high,
  //   ];

  //   // Propose
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_propose',
  //     CallData.compile({
  //       space: space.address,
  //       author: account.address,
  //       metadataURI: [],
  //       executionStrategy: {
  //         address: ethRelayer.address,
  //         params: executionPayload,
  //       },
  //       userProposalValidationParams: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   // Vote
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_vote',
  //     CallData.compile({
  //       space: space.address,
  //       voter: account.address,
  //       proposalId: { low: '0x1', high: '0x0' },
  //       choice: '0x2',
  //       userVotingStrategies: [{ index: '0x0', params: [] }],
  //       metadataURI: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   // Advance time so that the maxVotingTimestamp is exceeded
  //   await starknet.devnet.increaseTime(10);
  //   await increaseEthBlockchainTime(eth_network, 10);

  //   // Execute
  //   await account.invoke(
  //     space,
  //     'execute',
  //     CallData.compile({
  //       proposalId: { low: '0x1', high: '0x0' },
  //       executionPayload: executionPayload,
  //     }),
  //     { rawInput: true },
  //   );

  //   // Propagating message to L1
  //   const flushL2Response = await starknet.devnet.flush();
  //   const message_payload = flushL2Response.consumed_messages.from_l2[0].payload;
  //   // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
  //   const [proposalId, proposal, votes] = extractMessagePayload(message_payload);

  //   // For some reason CI fails with revertedWith('InvalidProposalStatus') but works locally.
  //   await expect(
  //     l1AvatarExecutionStrategy.execute(
  //       space.address,
  //       proposalId,
  //       proposal,
  //       votes,
  //       executionHash,
  //       [proposalTx],
  //     ),
  //   ).to.be.reverted;
  // }, 10000000);

  // it('should revert execution if quorum is not met (against votes only)', async function () {
  //   await starknet.devnet.restart();
  //   await starknet.devnet.load('./dump.pkl');
  //   await starknet.devnet.increaseTime(10);
  //   await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

  //   const proposalTx = {
  //     to: signer.address,
  //     value: 0,
  //     data: '0x22',
  //     operation: 0,
  //   };

  //   const abiCoder = new ethers.utils.AbiCoder();
  //   const executionHash = ethers.utils.keccak256(
  //     abiCoder.encode(
  //       ['tuple(address to, uint256 value, bytes data, uint8 operation)[]'],
  //       [[proposalTx]],
  //     ),
  //   );
  //   // Represent the execution hash as a Cairo Uint256
  //   const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

  //   const executionPayload = [
  //     l1AvatarExecutionStrategy.address,
  //     executionHashUint256.low,
  //     executionHashUint256.high,
  //   ];

  //   // Propose
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_propose',
  //     CallData.compile({
  //       space: space.address,
  //       author: account.address,
  //       metadataURI: [],
  //       executionStrategy: {
  //         address: ethRelayer.address,
  //         params: executionPayload,
  //       },
  //       userProposalValidationParams: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   // Vote
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_vote',
  //     CallData.compile({
  //       space: space.address,
  //       voter: account.address,
  //       proposalId: { low: '0x1', high: '0x0' },
  //       choice: '0x0',
  //       userVotingStrategies: [{ index: '0x0', params: [] }],
  //       metadataURI: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   // Advance time so that the maxVotingTimestamp is exceeded
  //   await starknet.devnet.increaseTime(10);
  //   await increaseEthBlockchainTime(eth_network, 10);

  //   // Execute
  //   await account.invoke(
  //     space,
  //     'execute',
  //     CallData.compile({
  //       proposalId: { low: '0x1', high: '0x0' },
  //       executionPayload: executionPayload,
  //     }),
  //     { rawInput: true },
  //   );

  //   // Propagating message to L1
  //   const flushL2Response = await starknet.devnet.flush();
  //   const message_payload = flushL2Response.consumed_messages.from_l2[0].payload;
  //   // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
  //   const [proposalId, proposal, votes] = extractMessagePayload(message_payload);

  //   // For some reason CI fails with revertedWith('InvalidProposalStatus') but works locally.
  //   await expect(
  //     l1AvatarExecutionStrategy.execute(
  //       space.address,
  //       proposalId,
  //       proposal,
  //       votes,
  //       executionHash,
  //       [proposalTx],
  //     ),
  //   ).to.be.reverted;
  // }, 10000000);

  // it('should revert execution if quorum is not met (no votes)', async function () {
  //   await starknet.devnet.restart();
  //   await starknet.devnet.load('./dump.pkl');
  //   await starknet.devnet.increaseTime(10);
  //   await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

  //   const proposalTx = {
  //     to: signer.address,
  //     value: 0,
  //     data: '0x22',
  //     operation: 0,
  //   };

  //   const abiCoder = new ethers.utils.AbiCoder();
  //   const executionHash = ethers.utils.keccak256(
  //     abiCoder.encode(
  //       ['tuple(address to, uint256 value, bytes data, uint8 operation)[]'],
  //       [[proposalTx]],
  //     ),
  //   );
  //   // Represent the execution hash as a Cairo Uint256
  //   const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

  //   const executionPayload = [
  //     l1AvatarExecutionStrategy.address,
  //     executionHashUint256.low,
  //     executionHashUint256.high,
  //   ];

  //   // Propose
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_propose',
  //     CallData.compile({
  //       space: space.address,
  //       author: account.address,
  //       metadataURI: [],
  //       executionStrategy: {
  //         address: ethRelayer.address,
  //         params: executionPayload,
  //       },
  //       userProposalValidationParams: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   // No Vote Cast

  //   // Advance time so that the maxVotingTimestamp is exceeded
  //   await starknet.devnet.increaseTime(10);
  //   await increaseEthBlockchainTime(eth_network, 10);

  //   // Execute
  //   await account.invoke(
  //     space,
  //     'execute',
  //     CallData.compile({
  //       proposalId: { low: '0x1', high: '0x0' },
  //       executionPayload: executionPayload,
  //     }),
  //     { rawInput: true },
  //   );

  //   // Propagating message to L1
  //   const flushL2Response = await starknet.devnet.flush();
  //   const message_payload = flushL2Response.consumed_messages.from_l2[0].payload;
  //   // Proposal data can either be extracted from the message sent to L1 (as done here) or pulled from the contract directly
  //   const [proposalId, proposal, votes] = extractMessagePayload(message_payload);

  //   // For some reason CI fails with revertedWith('InvalidProposalStatus') but works locally.
  //   await expect(
  //     l1AvatarExecutionStrategy.execute(
  //       space.address,
  //       proposalId,
  //       proposal,
  //       votes,
  //       executionHash,
  //       [proposalTx],
  //     ),
  //   ).to.be.reverted;
  // }, 10000000);

  // it('should revert execution if voting period is not exceeded', async function () {
  //   await starknet.devnet.restart();
  //   await starknet.devnet.load('./dump.pkl');
  //   await starknet.devnet.increaseTime(10);

  //   await starknet.devnet.loadL1MessagingContract(eth_network, mockStarknetMessaging.address);

  //   const proposalTx = {
  //     to: signer.address,
  //     value: 0,
  //     data: '0x22',
  //     operation: 0,
  //   };

  //   const abiCoder = new ethers.utils.AbiCoder();
  //   const executionHash = ethers.utils.keccak256(
  //     abiCoder.encode(
  //       ['tuple(address to, uint256 value, bytes data, uint8 operation)[]'],
  //       [[proposalTx]],
  //     ),
  //   );
  //   // Represent the execution hash as a Cairo Uint256
  //   const executionHashUint256: Uint256 = uint256.bnToUint256(executionHash);

  //   const executionPayload = [
  //     l1AvatarExecutionStrategy.address,
  //     executionHashUint256.low,
  //     executionHashUint256.high,
  //   ];

  //   // Propose
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_propose',
  //     CallData.compile({
  //       space: space.address,
  //       author: account.address,
  //       metadataURI: [],
  //       executionStrategy: {
  //         address: ethRelayer.address,
  //         params: executionPayload,
  //       },
  //       userProposalValidationParams: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   // Vote
  //   await account.invoke(
  //     starkTxAuthenticator,
  //     'authenticate_vote',
  //     CallData.compile({
  //       space: space.address,
  //       voter: account.address,
  //       proposalId: { low: '0x1', high: '0x0' },
  //       choice: '0x1',
  //       userVotingStrategies: [{ index: '0x0', params: [] }],
  //       metadataURI: [],
  //     }),
  //     { rawInput: true },
  //   );

  //   try {
  //     // Execute before maxVotingTimestamp is exceeded
  //     await account.invoke(
  //       space,
  //       'execute',
  //       CallData.compile({
  //         proposalId: { low: '0x1', high: '0x0' },
  //         executionPayload: executionPayload,
  //       }),
  //       { rawInput: true },
  //     );
  //   } catch (err: any) {
  //     // 'Before max end timestamp' error message
  //     expect(err.message).to.contain('0x4265666f7265206d617820656e642074696d657374616d70');
  //   }
  // }, 10000000);
});
