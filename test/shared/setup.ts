import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { StarknetContract, Account } from 'hardhat/types';
import { Contract, ContractFactory } from 'ethers';
import { AddressZero } from '@ethersproject/constants';
import { executeContractCallWithSigners } from './safeUtils';
import { utils } from '@snapshot-labs/sx';

export interface Fossil {
  factsRegistry: StarknetContract;
  l1HeadersStore: StarknetContract;
  l1RelayerAccount: Account;
}

export async function vanillaSetup() {
  // We make the space controller public key the same as the public key of the space account itself
  const controller = (await starknet.deployAccount('OpenZeppelin')) as Account;
  const spaceFactory = await starknet.getContractFactory('./contracts/starknet/SpaceAccount.cairo');
  const vanillaVotingStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const vanillaAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/Authenticators/Vanilla.cairo'
  );
  const vanillaExecutionStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  const deployments = [
    vanillaAuthenticatorFactory.deploy(),
    vanillaVotingStrategyFactory.deploy(),
    vanillaExecutionStrategyFactory.deploy(),
  ];
  const contracts = await Promise.all(deployments);
  const vanillaAuthenticator = contracts[0] as StarknetContract;
  const vanillaVotingStrategy = contracts[1] as StarknetContract;
  const vanillaExecutionStrategy = contracts[2] as StarknetContract;

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: bigint[] = [BigInt(vanillaVotingStrategy.address)];
  const votingStrategyParams: bigint[][] = [[]]; // No params for the vanilla voting strategy
  const votingStrategyParamsFlat: bigint[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: bigint[] = [BigInt(vanillaAuthenticator.address)];
  const executors: bigint[] = [BigInt(vanillaExecutionStrategy.address)];
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  console.log('Deploying space contract...');
  const space = (await spaceFactory.deploy({
    public_key: BigInt(controller.publicKey),
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: BigInt(controller.starknetContract.address),
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    executors: executors,
  })) as StarknetContract;
  console.log('deployed!');

  return {
    space,
    controller,
    vanillaAuthenticator,
    vanillaVotingStrategy,
    vanillaExecutionStrategy,
  };
}

export async function zodiacRelayerSetup() {
  const controller = (await starknet.deployAccount('OpenZeppelin')) as Account;
  const spaceFactory = await starknet.getContractFactory('./contracts/starknet/SpaceAccount.cairo');
  const vanillaVotingStategyFactory = await starknet.getContractFactory(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const vanillaAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/Authenticators/Vanilla.cairo'
  );
  const zodiacRelayerFactory = await starknet.getContractFactory(
    './contracts/starknet/ExecutionStrategies/ZodiacRelayer.cairo'
  );

  const deployments = [
    vanillaAuthenticatorFactory.deploy(),
    vanillaVotingStategyFactory.deploy(),
    zodiacRelayerFactory.deploy(),
  ];
  const contracts = await Promise.all(deployments);
  const vanillaAuthenticator = contracts[0] as StarknetContract;
  const vanillaVotingStrategy = contracts[1] as StarknetContract;
  const zodiacRelayer = contracts[2] as StarknetContract;

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: bigint[] = [BigInt(vanillaVotingStrategy.address)];
  const votingStrategyParams: bigint[][] = [[]]; // No params for the vanilla voting strategy
  const votingStrategyParamsFlat: bigint[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: bigint[] = [BigInt(vanillaAuthenticator.address)];
  const executors: bigint[] = [BigInt(zodiacRelayer.address)];
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  const space = (await spaceFactory.deploy({
    public_key: BigInt(controller.publicKey),
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: BigInt(controller.starknetContract.address),
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    executors: executors,
  })) as StarknetContract;

  // Deploying StarkNet core instance required for L2 -> L1 message passing
  const mockStarknetMessagingFactory = (await ethers.getContractFactory(
    'MockStarknetMessaging'
  )) as ContractFactory;
  const mockStarknetMessaging = await mockStarknetMessagingFactory.deploy();
  await mockStarknetMessaging.deployed();

  // Deploying zodiac module
  const { zodiacModule, safe, safeSigner } = await safeWithZodiacSetup(
    mockStarknetMessaging.address,
    BigInt(space.address),
    BigInt(zodiacRelayer.address)
  );

  return {
    space,
    controller,
    vanillaAuthenticator,
    vanillaVotingStrategy,
    zodiacRelayer,
    zodiacModule,
    mockStarknetMessaging,
  };
}

export async function safeWithZodiacSetup(
  starknetCoreAddress = '0x0000000000000000000000000000000000000001',
  spaceAddress = BigInt(0),
  zodiacRelayerAddress = BigInt(0)
) {
  const wallets = await ethers.getSigners();
  const safeSigner = wallets[0]; // One 1 signer on the safe

  const GnosisSafeL2 = await ethers.getContractFactory(
    '@gnosis.pm/safe-contracts/contracts/GnosisSafeL2.sol:GnosisSafeL2'
  );
  const FactoryContract = await ethers.getContractFactory(
    '@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol:GnosisSafeProxyFactory'
  );
  const singleton = await GnosisSafeL2.deploy();
  const factory = await FactoryContract.deploy();

  const template = await factory.callStatic.createProxy(singleton.address, '0x');
  await factory.createProxy(singleton.address, '0x');

  const safe = GnosisSafeL2.attach(template);
  safe.setup([safeSigner.address], 1, AddressZero, '0x', AddressZero, AddressZero, 0, AddressZero);

  const moduleFactoryContract = await ethers.getContractFactory('ModuleProxyFactory');
  const moduleFactory = await moduleFactoryContract.deploy();

  const SnapshotXContract = await ethers.getContractFactory('SnapshotXL1Executor');

  //deploying singleton master contract
  const masterzodiacModule = await SnapshotXContract.deploy(
    '0x0000000000000000000000000000000000000001',
    '0x0000000000000000000000000000000000000001',
    '0x0000000000000000000000000000000000000001',
    '0x0000000000000000000000000000000000000001',
    1,
    []
  );

  const encodedInitParams = ethers.utils.defaultAbiCoder.encode(
    ['address', 'address', 'address', 'address', 'uint256', 'uint256[]'],
    [
      safe.address,
      safe.address,
      safe.address,
      starknetCoreAddress,
      zodiacRelayerAddress,
      [spaceAddress],
    ]
  );

  const initData = masterzodiacModule.interface.encodeFunctionData('setUp', [encodedInitParams]);

  const masterCopyAddress = masterzodiacModule.address.toLowerCase().replace(/^0x/, '');

  //This is the bytecode of the module proxy contract
  const byteCode =
    '0x602d8060093d393df3363d3d373d3d3d363d73' +
    masterCopyAddress +
    '5af43d82803e903d91602b57fd5bf3';

  const salt = ethers.utils.solidityKeccak256(
    ['bytes32', 'uint256'],
    [ethers.utils.solidityKeccak256(['bytes'], [initData]), '0x01']
  );

  const expectedAddress = ethers.utils.getCreate2Address(
    moduleFactory.address,
    salt,
    ethers.utils.keccak256(byteCode)
  );

  expect(await moduleFactory.deployModule(masterzodiacModule.address, initData, '0x01'))
    .to.emit(moduleFactory, 'ModuleProxyCreation')
    .withArgs(expectedAddress, masterzodiacModule.address);
  const zodiacModule = SnapshotXContract.attach(expectedAddress);

  await executeContractCallWithSigners(
    safe,
    safe,
    'enableModule',
    [zodiacModule.address],
    [safeSigner]
  );

  return {
    zodiacModule: zodiacModule as Contract,
    safe: safe as Contract,
    safeSigner: safeSigner as SignerWithAddress,
  };
}

export async function ethTxAuthSetup() {
  const controller = (await starknet.deployAccount('OpenZeppelin')) as Account;
  const spaceFactory = await starknet.getContractFactory('./contracts/starknet/SpaceAccount.cairo');
  const vanillaVotingStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const ethTxAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/Authenticators/EthTx.cairo'
  );
  const vanillaExecutionStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  // Deploying StarkNet core instance required for L1 -> L2 message passing
  const mockStarknetMessagingFactory = (await ethers.getContractFactory(
    'MockStarknetMessaging'
  )) as ContractFactory;
  const mockStarknetMessaging = (await mockStarknetMessagingFactory.deploy()) as Contract;
  await mockStarknetMessaging.deployed();
  const starknetCore = mockStarknetMessaging.address;

  // Deploy StarkNet Commit L1 contract
  const starknetCommitFactory = (await ethers.getContractFactory(
    'StarkNetCommit'
  )) as ContractFactory;
  const starknetCommit = (await starknetCommitFactory.deploy(starknetCore)) as Contract;

  const deployments = [
    ethTxAuthenticatorFactory.deploy({ starknet_commit_address: BigInt(starknetCommit.address) }),
    vanillaVotingStrategyFactory.deploy(),
    vanillaExecutionStrategyFactory.deploy(),
  ];
  const contracts = await Promise.all(deployments);
  const ethTxAuthenticator = contracts[0] as StarknetContract;
  const vanillaVotingStrategy = contracts[1] as StarknetContract;
  const vanillaExecutionStrategy = contracts[2] as StarknetContract;

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  );
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1));
  const votingStrategies: bigint[] = [BigInt(vanillaVotingStrategy.address)];
  const votingStrategyParams: bigint[][] = [[]];
  const votingStrategyParamsFlat: bigint[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: bigint[] = [BigInt(ethTxAuthenticator.address)];
  const executors: bigint[] = [BigInt(vanillaExecutionStrategy.address)];

  console.log('Deploying space contract...');
  const space = (await spaceFactory.deploy({
    public_key: BigInt(controller.publicKey),
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: BigInt(controller.starknetContract.address),
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    executors: executors,
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

export async function singleSlotProofSetup(block: any, proofs: any) {
  // We pass the encode params function for the single slot proof strategy to generate the encoded data for the single slot proof strategy
  const proofInputs: utils.storageProofs.ProofInputs = utils.storageProofs.getProofInputs(
    block.number,
    proofs
  );

  const controller = await starknet.deployAccount('OpenZeppelin');

  const fossil = await fossilSetup(controller);

  const spaceFactory = await starknet.getContractFactory('./contracts/starknet/SpaceAccount.cairo');
  const singleSlotProofStrategyFactory = await starknet.getContractFactory(
    'contracts/starknet/VotingStrategies/SingleSlotProof.cairo'
  );
  const vanillaAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/Authenticators/Vanilla.cairo'
  );
  const vanillaExecutionStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );
  const deployments = [
    vanillaAuthenticatorFactory.deploy(),
    singleSlotProofStrategyFactory.deploy({
      fact_registry_address: BigInt(fossil.factsRegistry.address),
      l1_headers_store_address: BigInt(fossil.l1HeadersStore.address),
    }),
    vanillaExecutionStrategyFactory.deploy(),
  ];
  const contracts = await Promise.all(deployments);
  const vanillaAuthenticator = contracts[0] as StarknetContract;
  const singleSlotProofStrategy = contracts[1] as StarknetContract;
  const vanillaExecutionStrategy = contracts[2] as StarknetContract;

  // Submit blockhash to L1 Headers Store (via dummy function rather than L1 -> L2 bridge)
  await fossil.l1RelayerAccount.invoke(fossil.l1HeadersStore, 'receive_from_l1', {
    parent_hash: utils.intsSequence.IntsSequence.fromBytes(utils.bytes.hexToBytes(block.hash))
      .values,
    block_number: block.number + 1,
  });

  // Encode block header and then submit to L1 Headers Store
  const processBlockInputs: utils.storageProofs.ProcessBlockInputs =
    utils.storageProofs.getProcessBlockInputs(block);
  await fossil.l1RelayerAccount.invoke(fossil.l1HeadersStore, 'process_block', {
    options_set: processBlockInputs.blockOptions,
    block_number: processBlockInputs.blockNumber,
    block_header_rlp_bytes_len: processBlockInputs.headerInts.bytesLength,
    block_header_rlp: processBlockInputs.headerInts.values,
  });

  const controllerAddress = BigInt(controller.starknetContract.address);
  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: bigint[] = [BigInt(singleSlotProofStrategy.address)];
  const votingStrategyParams: bigint[][] = [[proofInputs.ethAddressFelt, BigInt(0)]]; // For the aave erc20 contract, the balances mapping has a storage index of 0
  const votingStrategyParamsFlat: bigint[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: bigint[] = [BigInt(vanillaAuthenticator.address)];
  const executors: bigint[] = [BigInt(vanillaExecutionStrategy.address)];
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  // Deploy space with specified parameters
  const space = (await spaceFactory.deploy({
    public_key: BigInt(controller.publicKey),
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: controllerAddress,
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    executors: executors,
  })) as StarknetContract;

  return {
    space,
    controller,
    vanillaAuthenticator,
    singleSlotProofStrategy,
    vanillaExecutionStrategy,
    fossil,
    proofInputs,
  };
}

// Setup function to test the single slot proof strategy in isolation, ie not within context of space contract
export async function singleSlotProofSetupIsolated(block: any) {
  const account = await starknet.deployAccount('OpenZeppelin');
  const fossil = await fossilSetup(account);
  const singleSlotProofStrategyFactory = await starknet.getContractFactory(
    'contracts/starknet/VotingStrategies/SingleSlotProof.cairo'
  );
  const singleSlotProofStrategy = await singleSlotProofStrategyFactory.deploy({
    fact_registry_address: BigInt(fossil.factsRegistry.address),
    l1_headers_store_address: BigInt(fossil.l1HeadersStore.address),
  });
  // Submit blockhash to L1 Headers Store (via dummy function rather than L1 -> L2 bridge)
  await fossil.l1RelayerAccount.invoke(fossil.l1HeadersStore, 'receive_from_l1', {
    parent_hash: utils.intsSequence.IntsSequence.fromBytes(utils.bytes.hexToBytes(block.hash))
      .values,
    block_number: block.number + 1,
  });
  // Encode block header and then submit to L1 Headers Store
  const processBlockInputs: utils.storageProofs.ProcessBlockInputs =
    utils.storageProofs.getProcessBlockInputs(block);
  await fossil.l1RelayerAccount.invoke(fossil.l1HeadersStore, 'process_block', {
    options_set: processBlockInputs.blockOptions,
    block_number: processBlockInputs.blockNumber,
    block_header_rlp_bytes_len: processBlockInputs.headerInts.bytesLength,
    block_header_rlp: processBlockInputs.headerInts.values,
  });
  return {
    fossil: fossil as Fossil,
    singleSlotProofStrategy: singleSlotProofStrategy as StarknetContract,
    account: account as Account,
  };
}

async function fossilSetup(deployer: Account): Promise<Fossil> {
  const factsRegistryFactory = await starknet.getContractFactory(
    'fossil/contracts/starknet/FactsRegistry.cairo'
  );
  const l1HeadersStoreFactory = await starknet.getContractFactory(
    'fossil/contracts/starknet/L1HeadersStore.cairo'
  );
  const factsRegistry = await factsRegistryFactory.deploy();
  const l1HeadersStore = await l1HeadersStoreFactory.deploy();
  const l1RelayerAccount = await starknet.deployAccount('OpenZeppelin');
  await deployer.invoke(factsRegistry, 'initialize', {
    l1_headers_store_addr: BigInt(l1HeadersStore.address),
  });
  await deployer.invoke(l1HeadersStore, 'initialize', {
    l1_messages_origin: BigInt(l1RelayerAccount.starknetContract.address),
  });
  return {
    factsRegistry: factsRegistry as StarknetContract,
    l1HeadersStore: l1HeadersStore as StarknetContract,
    l1RelayerAccount: l1RelayerAccount as Account,
  };
}

export async function starknetAccountSetup() {
  const controller = await starknet.deployAccount('OpenZeppelin');

  const vanillaSpaceFactory = await starknet.getContractFactory(
    './contracts/starknet/SpaceAccount.cairo'
  );
  const vanillaVotingStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const starknetAccountAuthFactory = await starknet.getContractFactory(
    './contracts/starknet/Authenticators/StarkSig.cairo'
  );
  const zodiacRelayerFactory = await starknet.getContractFactory(
    './contracts/starknet/ExecutionStrategies/ZodiacRelayer.cairo'
  );

  const deployments = [
    starknetAccountAuthFactory.deploy(),
    vanillaVotingStrategyFactory.deploy(),
    zodiacRelayerFactory.deploy(),
  ];
  console.log('Deploying auth, voting and zodiac relayer contracts...');
  const contracts = await Promise.all(deployments);
  const starknetAccountAuth = contracts[0] as StarknetContract;
  const vanillaVotingStrategy = contracts[1] as StarknetContract;
  const zodiacRelayer = contracts[2] as StarknetContract;

  const voting_strategy = BigInt(vanillaVotingStrategy.address);
  const authenticator = BigInt(starknetAccountAuth.address);
  const zodiac_relayer = BigInt(zodiacRelayer.address);
  const quorum = utils.splitUint256.SplitUint256.fromUint(BigInt(0));
  const voting_strategy_params: bigint[][] = [[]];
  const voting_strategy_params_flat = utils.encoding.flatten2DArray(voting_strategy_params);

  // This should be declared along with the other const but doing so will make the compiler unhappy as `SplitUint256`
  // will be undefined for some reason?
  const PROPOSAL_THRESHOLD = utils.splitUint256.SplitUint256.fromUint(BigInt(1));

  console.log('Deploying space contract...');
  const vanillaSpace = (await vanillaSpaceFactory.deploy({
    public_key: BigInt(controller.publicKey),
    voting_delay: BigInt(0),
    min_voting_duration: BigInt(0),
    max_voting_duration: BigInt(2000),
    proposal_threshold: PROPOSAL_THRESHOLD,
    quorum: quorum,
    controller: BigInt(controller.starknetContract.address),
    voting_strategy_params_flat: voting_strategy_params_flat,
    voting_strategies: [voting_strategy],
    authenticators: [authenticator],
    executors: [zodiac_relayer],
  })) as StarknetContract;
  console.log('deployed!');

  return {
    vanillaSpace,
    starknetAccountAuth,
    vanillaVotingStrategy,
    zodiacRelayer,
    controller,
  };
}

export async function starkTxAuthSetup() {
  const controller = await starknet.deployAccount('OpenZeppelin');
  const spaceFactory = await starknet.getContractFactory('./contracts/starknet/SpaceAccount.cairo');
  const vanillaVotingStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const starknetTxAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/Authenticators/StarkTx.cairo'
  );
  const vanillaExecutionStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  const deployments = [
    starknetTxAuthenticatorFactory.deploy(),
    vanillaVotingStrategyFactory.deploy(),
    vanillaExecutionStrategyFactory.deploy(),
  ];
  const contracts = await Promise.all(deployments);
  const starknetTxAuthenticator = contracts[0] as StarknetContract;
  const vanillaVotingStrategy = contracts[1] as StarknetContract;
  const vanillaExecutionStrategy = contracts[2] as StarknetContract;

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: bigint[] = [BigInt(vanillaVotingStrategy.address)];
  const votingStrategyParams: bigint[][] = [[]]; // No params for the vanilla voting strategy
  const votingStrategyParamsFlat: bigint[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: bigint[] = [BigInt(starknetTxAuthenticator.address)];
  const executors: bigint[] = [BigInt(vanillaExecutionStrategy.address)];
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  console.log('Deploying space contract...');
  const space = (await spaceFactory.deploy({
    public_key: BigInt(controller.publicKey),
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: BigInt(controller.starknetContract.address),
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    executors: executors,
  })) as StarknetContract;
  console.log('deployed!');

  return {
    space,
    controller,
    starknetTxAuthenticator,
    vanillaVotingStrategy,
    vanillaExecutionStrategy,
  };
}

export async function ethereumSigAuthSetup() {
  const controller = await starknet.deployAccount('OpenZeppelin');

  const vanillaSpaceFactory = await starknet.getContractFactory(
    './contracts/starknet/SpaceAccount.cairo'
  );
  const vanillaVotingStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const ethSigAuthFactory = await starknet.getContractFactory(
    './contracts/starknet/Authenticators/EthSig.cairo'
  );
  const vanillaExecutionFactory = await starknet.getContractFactory(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  const deployments = [
    ethSigAuthFactory.deploy(),
    vanillaVotingStrategyFactory.deploy(),
    vanillaExecutionFactory.deploy(),
  ];
  console.log('Deploying auth, voting and zodiac relayer contracts...');
  const contracts = await Promise.all(deployments);
  const ethSigAuth = contracts[0] as StarknetContract;
  const vanillaVotingStrategy = contracts[1] as StarknetContract;
  const vanillaExecutionStrategy = contracts[2] as StarknetContract;

  const voting_strategy = BigInt(vanillaVotingStrategy.address);
  const authenticator = BigInt(ethSigAuth.address);
  const voting_execution = BigInt(vanillaExecutionStrategy.address);
  const quorum = utils.splitUint256.SplitUint256.fromUint(BigInt(0));

  const voting_strategy_params: bigint[][] = [[]];
  const voting_strategy_params_flat = utils.encoding.flatten2DArray(voting_strategy_params);

  // This should be declared along with the other const but doing so will make the compiler unhappy as `SplitUint256`
  // will be undefined for some reason?
  const PROPOSAL_THRESHOLD = utils.splitUint256.SplitUint256.fromUint(BigInt(1));

  console.log('Deploying space contract...');
  const vanillaSpace = (await vanillaSpaceFactory.deploy({
    public_key: BigInt(controller.publicKey),
    voting_delay: BigInt(0),
    min_voting_duration: BigInt(0),
    max_voting_duration: BigInt(2000),
    proposal_threshold: PROPOSAL_THRESHOLD,
    quorum: quorum,
    controller: BigInt(controller.address),
    voting_strategy_params_flat: voting_strategy_params_flat,
    voting_strategies: [voting_strategy],
    authenticators: [authenticator],
    executors: [voting_execution],
  })) as StarknetContract;

  console.log('deployed!');

  return {
    space: vanillaSpace,
    controller,
    ethSigAuth,
    vanillaVotingStrategy,
    vanillaExecutionStrategy,
  };
}

export async function spaceFactorySetup() {
  const controller = (await starknet.deployAccount('OpenZeppelin')) as Account;
  const spaceDeployerFactory = await starknet.getContractFactory(
    './contracts/starknet/SpaceFactory.cairo'
  );

  const spaceFactoryClass = await starknet.getContractFactory(
    './contracts/starknet/SpaceAccount.cairo'
  );
  const spaceHash = await spaceFactoryClass.declare();

  const vanillaVotingStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const vanillaAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/Authenticators/Vanilla.cairo'
  );
  const vanillaExecutionStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  const deployments = [
    vanillaAuthenticatorFactory.deploy(),
    vanillaVotingStrategyFactory.deploy(),
    vanillaExecutionStrategyFactory.deploy(),
    spaceDeployerFactory.deploy({ space_class_hash: spaceHash }),
  ];
  const contracts = await Promise.all(deployments);
  const vanillaAuthenticator = contracts[0] as StarknetContract;
  const vanillaVotingStrategy = contracts[1] as StarknetContract;
  const vanillaExecutionStrategy = contracts[2] as StarknetContract;
  const spaceDeployer = contracts[3] as StarknetContract;

  return {
    spaceDeployer,
    spaceFactoryClass,
    controller,
    vanillaAuthenticator,
    vanillaVotingStrategy,
    vanillaExecutionStrategy,
  };
}

export async function starknetExecutionSetup() {
  const controller = (await starknet.deployAccount('OpenZeppelin')) as Account;
  const spaceFactory = await starknet.getContractFactory('./contracts/starknet/SpaceAccount.cairo');
  const vanillaVotingStrategyFactory = await starknet.getContractFactory(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const vanillaAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/Authenticators/Vanilla.cairo'
  );
  // const starknetExecutionStrategyFactory = await starknet.getContractFactory(
  //   './contracts/starknet/ExecutionStrategies/Starknet.cairo'
  // );

  const deployments = [vanillaAuthenticatorFactory.deploy(), vanillaVotingStrategyFactory.deploy()];
  const contracts = await Promise.all(deployments);
  const vanillaAuthenticator = contracts[0] as StarknetContract;
  const vanillaVotingStrategy = contracts[1] as StarknetContract;
  const starknetExecutionStrategy = contracts[2] as StarknetContract;

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: bigint[] = [BigInt(vanillaVotingStrategy.address)];
  const votingStrategyParams: bigint[][] = [[]]; // No params for the vanilla voting strategy
  const votingStrategyParamsFlat: bigint[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: bigint[] = [BigInt(vanillaAuthenticator.address)];
  const executors: bigint[] = [BigInt(1), BigInt(1234), BigInt(4567), BigInt(456789)]; // We add dummy executors that get used in the test transactions
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  console.log('Deploying space contract...');
  const space = (await spaceFactory.deploy({
    public_key: BigInt(controller.publicKey),
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: BigInt(controller.starknetContract.address),
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    executors: executors,
  })) as StarknetContract;
  console.log('deployed!');

  return {
    space,
    controller,
    vanillaAuthenticator,
    vanillaVotingStrategy,
    starknetExecutionStrategy,
  };
}
