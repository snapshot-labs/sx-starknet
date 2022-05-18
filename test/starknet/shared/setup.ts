import { starknet, ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { StarknetContract, Account } from 'hardhat/types';
import { Contract, ContractFactory } from 'ethers';
import { SplitUint256, IntsSequence } from './types';
import { hexToBytes, flatten2DArray } from './helpers';
import { block } from '../data/blocks';
import { ProcessBlockInputs } from './parseRPCData';
export const EXECUTE_METHOD = 'execute';
export const PROPOSAL_METHOD = 'propose';
export const VOTE_METHOD = 'vote';
export const GET_PROPOSAL_INFO = 'get_proposal_info';
export const GET_VOTE_INFO = 'get_vote_info';
export const VOTING_DELAY = BigInt(0);
export const MIN_VOTING_DURATION = BigInt(0);
export const MAX_VOTING_DURATION = BigInt(2000);
export const VITALIK_ADDRESS = BigInt('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');
export const VITALIK_STRING_ADDRESS = '0x' + VITALIK_ADDRESS.toString(16);

export async function vanillaSetup() {
  const controller = await starknet.deployAccount('OpenZeppelin') as Account;
  const spaceFactory = await starknet.getContractFactory('./contracts/starknet/space.cairo');
  const vanillaVotingStategyFactory = await starknet.getContractFactory(
    './contracts/starknet/voting_strategies/vanilla.cairo'
  );
  const vanillaAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/authenticators/vanilla.cairo'
  );
  const vanillaExecutionStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/execution_strategies/vanilla.cairo'
  );

  const deployments = [
    vanillaAuthenticatorFactory.deploy(),
    vanillaVotingStategyFactory.deploy(),
    vanillaExecutionStrategyFactory.deploy(),
  ];
  const contracts = await Promise.all(deployments);
  const vanillaAuthenticator = contracts[0] as StarknetContract;
  const vanillaVotingStrategy = contracts[1] as StarknetContract;
  const vanillaExecutionStrategy = contracts[2] as StarknetContract;

  const votingDelay: bigint = BigInt(0);
  const minVotingDuration: bigint = BigInt(0);
  const maxVotingDuration:bigint = BigInt(2000);
  const votingStrategies: bigint[] = [BigInt(vanillaVotingStrategy.address)];
  const globalVotingStrategyParams: bigint[][] = [[]]; // No global params for the vanilla voting strategy
  const globalVotingStrategyParamsFlat: bigint[] = flatten2DArray(globalVotingStrategyParams);
  const authenticators: bigint[] = [BigInt(vanillaAuthenticator.address)];
  const executors: bigint[] = [BigInt(vanillaExecutionStrategy.address)];
  const quorum: SplitUint256 = SplitUint256.fromUint(BigInt(1)); //  Quorum of one for the vanilla test
  const proposalThreshold: SplitUint256 = SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  console.log('Deploying space contract...');
  const space = (await spaceFactory.deploy({
    _voting_delay: votingDelay,
    _min_voting_duration: minVotingDuration,
    _max_voting_duration: maxVotingDuration,
    _proposal_threshold: proposalThreshold,
    _controller: BigInt(controller.starknetContract.address),
    _quorum: quorum,
    _global_voting_strategy_params_flat: globalVotingStrategyParamsFlat,
    _voting_strategies: votingStrategies,
    _authenticators: authenticators,
    _executors: executors,
  })) as StarknetContract;
  console.log('deployed!');

  return {
    space,
    controller,
    vanillaAuthenticator,
    vanillaVotingStrategy,
    vanillaExecutionStrategy
  };
}

export async function ethTxAuthSetup(signer: SignerWithAddress) {
  const controller = await starknet.deployAccount('OpenZeppelin') as Account;
  const spaceFactory = await starknet.getContractFactory('./contracts/starknet/space.cairo');
  const vanillaVotingStategyFactory = await starknet.getContractFactory(
    './contracts/starknet/voting_strategies/vanilla.cairo'
  );
  const ethTxAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/authenticators/eth_tx.cairo'
  );
  const vanillaExecutionStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/execution_strategies/vanilla.cairo'
  );



  // Deploying StarkNet core instance required for L1 -> L2 message passing
  const mockStarknetMessagingFactory = (await ethers.getContractFactory(
    'MockStarknetMessaging',
    signer
  )) as ContractFactory;
  const mockStarknetMessaging = (await mockStarknetMessagingFactory.deploy()) as Contract;
  await mockStarknetMessaging.deployed();
  const starknetCore = mockStarknetMessaging.address;

  // Deploy StarkNet Commit L1 contract
  const starknetCommitFactory = (await ethers.getContractFactory(
    'StarkNetCommit',
    signer
  )) as ContractFactory;
  const starknetCommit = (await starknetCommitFactory.deploy(starknetCore)) as Contract;
  
  const deployments = [
    ethTxAuthenticatorFactory.deploy({starknet_commit_address: BigInt(starknetCommit.address)}),
    vanillaVotingStategyFactory.deploy(),
    vanillaExecutionStrategyFactory.deploy(),
  ];
  const contracts = await Promise.all(deployments);
  const ethTxAuthenticator = contracts[0] as StarknetContract;
  const vanillaVotingStrategy = contracts[1] as StarknetContract;
  const vanillaExecutionStrategy = contracts[2] as StarknetContract;

  const votingDelay: bigint = BigInt(0);
  const minVotingDuration: bigint = BigInt(0);
  const maxVotingDuration:bigint = BigInt(2000);
  const quorum: SplitUint256 = SplitUint256.fromUint(BigInt(1)); 
  const proposalThreshold: SplitUint256 = SplitUint256.fromUint(BigInt(1)); 
  const votingStrategies: bigint[] = [BigInt(vanillaVotingStrategy.address)];
  const globalVotingStrategyParams: bigint[][] = [[]];
  const globalVotingStrategyParamsFlat: bigint[] = flatten2DArray(globalVotingStrategyParams);
  const authenticators: bigint[] = [BigInt(ethTxAuthenticator.address)];
  const executors: bigint[] = [BigInt(vanillaExecutionStrategy.address)];

  console.log('Deploying space contract...');
  const space = (await spaceFactory.deploy({
    _voting_delay: votingDelay,
    _min_voting_duration: minVotingDuration,
    _max_voting_duration: maxVotingDuration,
    _proposal_threshold: proposalThreshold,
    _controller: BigInt(controller.starknetContract.address),
    _quorum: quorum,
    _global_voting_strategy_params_flat: globalVotingStrategyParamsFlat,
    _voting_strategies: votingStrategies,
    _authenticators: authenticators,
    _executors: executors,
  })) as StarknetContract;

  // Setting the L1 tx authenticator address in the StarkNet commit contract
  await starknetCommit.setAuth(BigInt(ethTxAuthenticator.address));

  return {
    space,
    controller,
    ethTxAuthenticator,
    vanillaVotingStrategy,
    vanillaExecutionStrategy,
    mockStarknetMessaging,
    starknetCommit,
  };
}

export async function singleSlotProofSetup() {
  const account = await starknet.deployAccount('OpenZeppelin');
  const fossil = await fossilSetup(account);
  const singleSlotProofStrategyFactory = await starknet.getContractFactory(
    'contracts/starknet/voting_strategies/single_slot_proof.cairo'
  );
  const singleSlotProofStrategy = await singleSlotProofStrategyFactory.deploy({
    fact_registry: BigInt(fossil.factsRegistry.address),
  });
  // Submit blockhash to L1 Headers Store (via dummy function rather than L1 -> L2 bridge)
  await fossil.l1RelayerAccount.invoke(fossil.l1HeadersStore, 'receive_from_l1', {
    parent_hash: IntsSequence.fromBytes(hexToBytes(block.hash)).values,
    block_number: block.number + 1,
  });
  // Encode block header and then submit to L1 Headers Store
  const processBlockInputs = ProcessBlockInputs.fromBlockRPCData(block);
  await fossil.l1RelayerAccount.invoke(fossil.l1HeadersStore, 'process_block', {
    options_set: processBlockInputs.blockOptions,
    block_number: processBlockInputs.blockNumber,
    block_header_rlp_bytes_len: processBlockInputs.headerInts.bytesLength,
    block_header_rlp: processBlockInputs.headerInts.values,
  });
  return {
    account: account as Account,
    singleSlotProofStrategy: singleSlotProofStrategy as StarknetContract,
    fossil: fossil as Fossil,
  };
}

class Fossil {
  factsRegistry: StarknetContract;
  l1HeadersStore: StarknetContract;
  l1RelayerAccount: Account;

  constructor(
    factsRegistry: StarknetContract,
    l1HeadersStore: StarknetContract,
    l1RelayerAccount: Account
  ) {
    this.factsRegistry = factsRegistry;
    this.l1HeadersStore = l1HeadersStore;
    this.l1RelayerAccount = l1RelayerAccount;
  }
}

async function fossilSetup(account: Account) {
  const factsRegistryFactory = await starknet.getContractFactory(
    'fossil/contracts/starknet/FactsRegistry.cairo'
  );
  const l1HeadersStoreFactory = await starknet.getContractFactory(
    'fossil/contracts/starknet/L1HeadersStore.cairo'
  );
  const factsRegistry = await factsRegistryFactory.deploy();
  const l1HeadersStore = await l1HeadersStoreFactory.deploy();
  const l1RelayerAccount = await starknet.deployAccount('OpenZeppelin');
  await account.invoke(factsRegistry, 'initialize', {
    l1_headers_store_addr: BigInt(l1HeadersStore.address),
  });
  await account.invoke(l1HeadersStore, 'initialize', {
    l1_messages_origin: BigInt(l1RelayerAccount.starknetContract.address),
  });
  return new Fossil(factsRegistry, l1HeadersStore, l1RelayerAccount);
}
