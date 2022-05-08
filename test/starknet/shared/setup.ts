import { starknet, ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { StarknetContract, Account } from 'hardhat/types';
import { Contract, ContractFactory } from 'ethers';
import { SplitUint256, IntsSequence } from './types';
import { hexToBytes } from './helpers';
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
export const VITALIK_STRING_ADDRESS = VITALIK_ADDRESS.toString(16);

export async function vanillaSetup() {
  const account = await starknet.deployAccount('OpenZeppelin');

  const vanillaSpaceFactory = await starknet.getContractFactory('./contracts/starknet/space.cairo');
  const vanillaVotingStategyFactory = await starknet.getContractFactory(
    './contracts/starknet/voting_strategies/vanilla.cairo'
  );
  const vanillaAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/authenticators/vanilla.cairo'
  );
  const zodiacRelayerFactory = await starknet.getContractFactory(
    './contracts/starknet/execution_strategies/zodiac_relayer.cairo'
  );

  const deployments = [
    vanillaAuthenticatorFactory.deploy(),
    vanillaVotingStategyFactory.deploy(),
    zodiacRelayerFactory.deploy(),
  ];
  console.log('Deploying auth, voting and zodiac relayer contracts...');
  const contracts = await Promise.all(deployments);
  const vanillaAuthenticator = contracts[0] as StarknetContract;
  const vanillaVotingStrategy = contracts[1] as StarknetContract;
  const zodiacRelayer = contracts[2] as StarknetContract;

  const voting_strategy = BigInt(vanillaVotingStrategy.address);
  const authenticator = BigInt(vanillaAuthenticator.address);
  const zodiac_relayer = BigInt(zodiacRelayer.address);

  // This should be declared along with the other const but doing so will make the compiler unhappy as `SplitUin256`
  // will be undefined for some reason?
  const PROPOSAL_THRESHOLD = SplitUint256.fromUint(BigInt(1));

  console.log('Deploying space contract...');
  const vanillaSpace = (await vanillaSpaceFactory.deploy({
    _voting_delay: VOTING_DELAY,
    _min_voting_duration: MIN_VOTING_DURATION,
    _max_voting_duration: MAX_VOTING_DURATION,
    _proposal_threshold: PROPOSAL_THRESHOLD,
    _controller: BigInt(account.starknetContract.address),
    _voting_strategies: [voting_strategy],
    _authenticators: [authenticator],
    _executors: [zodiac_relayer],
  })) as StarknetContract;
  console.log('deployed!');

  return {
    vanillaSpace,
    vanillaAuthenticator,
    vanillaVotingStrategy,
    zodiacRelayer,
    account,
  };
}

export async function ethTxAuthSetup(signer: SignerWithAddress) {
  const SpaceFactory = await starknet.getContractFactory('./contracts/starknet/space.cairo');
  const vanillaVotingStategyFactory = await starknet.getContractFactory(
    './contracts/starknet/voting_strategies/vanilla.cairo'
  );
  const EthTxAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/authenticators/eth_tx.cairo'
  );

  const MockStarknetMessagingFactory = (await ethers.getContractFactory(
    'MockStarknetMessaging',
    signer
  )) as ContractFactory;
  const mockStarknetMessaging = (await MockStarknetMessagingFactory.deploy()) as Contract;
  await mockStarknetMessaging.deployed();

  const starknetCore = mockStarknetMessaging.address;

  // Deploy StarkNet Commit L1 contract
  const StarknetCommitFactory = (await ethers.getContractFactory(
    'StarkNetCommit',
    signer
  )) as ContractFactory;
  const starknetCommit = (await StarknetCommitFactory.deploy(starknetCore)) as Contract;
  const starknet_commit = BigInt(starknetCommit.address);

  console.log('Deploying auth...');
  const ethTxAuthenticator = (await EthTxAuthenticatorFactory.deploy({
    starknet_commit_address: starknet_commit,
  })) as StarknetContract;
  console.log('Deploying strat...');
  const vanillaVotingStrategy = (await vanillaVotingStategyFactory.deploy()) as StarknetContract;
  const voting_strategy = BigInt(vanillaVotingStrategy.address);
  const authenticator = BigInt(ethTxAuthenticator.address);
  console.log('Deploying space...');

  // This should be declared along with the other const but doing so will make the compiler unhappy as `SplitUin256`
  // will be undefined for some reason?
  const PROPOSAL_THRESHOLD = SplitUint256.fromUint(BigInt(1));

  const space = (await SpaceFactory.deploy({
    _voting_delay: VOTING_DELAY,
    _min_voting_duration: MIN_VOTING_DURATION,
    _max_voting_duration: MAX_VOTING_DURATION,
    _proposal_threshold: PROPOSAL_THRESHOLD,
    _controller: 1,
    _voting_strategies: [voting_strategy],
    _authenticators: [authenticator],
    _executors: [VITALIK_ADDRESS],
  })) as StarknetContract;
  // Setting the L1 tx authenticator address in the StarkNet commit contract
  await starknetCommit.setAuth(authenticator);

  return {
    space,
    ethTxAuthenticator,
    vanillaVotingStrategy,
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
