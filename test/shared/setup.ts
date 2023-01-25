import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { StarknetContract, Account } from 'hardhat/types';
import { Contract, ContractFactory } from 'ethers';
import { AddressZero } from '@ethersproject/constants';
import { executeContractCallWithSigners } from './safeUtils';
import { utils } from '@snapshot-labs/sx';
import { declareAndDeployContract, getAccount } from '../utils/deploy';
import { OpenZeppelinAccount } from '@shardlabs/starknet-hardhat-plugin/dist/src/account';

export interface Fossil {
  factsRegistry: StarknetContract;
  l1HeadersStore: StarknetContract;
  l1RelayerAccount: Account;
}

export async function vanillaSetup() {
  // We make the space controller public key the same as the public key of the space account itself
  const controller = await getAccount(1);

  const vanillaAuthenticator = await declareAndDeployContract(
    './contracts/starknet/Authenticators/Vanilla.cairo'
  );
  const vanillaVotingStrategy = await declareAndDeployContract(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const vanillaExecutionStrategy = await declareAndDeployContract(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: string[] = [vanillaVotingStrategy.address];
  const votingStrategyParams: string[][] = [[]]; // No params for the vanilla voting strategy
  const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: string[] = [vanillaAuthenticator.address];
  const execution_strategies: string[] = [vanillaExecutionStrategy.address];
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  const args = {
    public_key: controller.publicKey,
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: controller.starknetContract.address,
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    execution_strategies: execution_strategies,
  };

  console.log('Deploying space contract...');
  const space = await declareAndDeployContract(
    './contracts/starknet/SpaceAccount.cairo',
    args,
    controller
  );

  return {
    space,
    controller,
    vanillaAuthenticator,
    vanillaVotingStrategy,
    vanillaExecutionStrategy,
  };
}

export async function zodiacRelayerSetup() {
  const controller = await getAccount(1);
  const spaceFactory = await starknet.getContractFactory('./contracts/starknet/SpaceAccount.cairo');

  const vanillaAuthenticator = await declareAndDeployContract(
    './contracts/starknet/Authenticators/Vanilla.cairo'
  );
  const vanillaVotingStrategy = await declareAndDeployContract(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const zodiacRelayer = await declareAndDeployContract(
    './contracts/starknet/ExecutionStrategies/EthRelayer.cairo'
  );

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: string[] = [vanillaVotingStrategy.address];
  const votingStrategyParams: string[][] = [[]]; // No params for the vanilla voting strategy
  const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: string[] = [vanillaAuthenticator.address];
  const execution_strategies: string[] = [zodiacRelayer.address];
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  const args = {
    public_key: controller.publicKey,
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: controller.starknetContract.address,
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    execution_strategies: execution_strategies,
  };

  const space = await declareAndDeployContract('./contracts/starknet/SpaceAccount.cairo', args);

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
  const controller = await getAccount(1);

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

  const ethTxAuth = await declareAndDeployContract(
    './contracts/starknet/Authenticators/EthTx.cairo',
    {
      starknet_commit_address: BigInt(starknetCommit.address),
    }
  );
  const vanillaVotingStrategy = await declareAndDeployContract(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const vanillaExecutionStrategy = await declareAndDeployContract(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  );
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1));
  const votingStrategies: string[] = [vanillaVotingStrategy.address];
  const votingStrategyParams: string[][] = [[]];
  const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: string[] = [ethTxAuth.address];
  const execution_strategies: string[] = [vanillaExecutionStrategy.address];

  const args = {
    public_key: controller.publicKey,
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: controller.starknetContract.address,
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    execution_strategies: execution_strategies,
  };

  console.log('Deploying space contract...');
  const space = await declareAndDeployContract('./contracts/starknet/SpaceAccount.cairo', args);

  return {
    space,
    controller,
    ethTxAuth,
    vanillaVotingStrategy,
    vanillaExecutionStrategy,
    mockStarknetMessaging,
    starknetCommit,
  };
}

export async function ethTxSessionKeyAuthSetup() {
  const controller = await getAccount(1);
  const spaceFactory = await starknet.getContractFactory('./contracts/starknet/SpaceAccount.cairo');

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

  const ethTxSessionKeyAuth = await declareAndDeployContract(
    './contracts/starknet/Authenticators/EthTxSessionKey.cairo',
    {
      starknet_commit_address: BigInt(starknetCommit.address),
    }
  );
  const vanillaVotingStrategy = await declareAndDeployContract(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const vanillaExecutionStrategy = await declareAndDeployContract(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  );
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1));
  const votingStrategies: string[] = [vanillaVotingStrategy.address];
  const votingStrategyParams: string[][] = [[]];
  const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: string[] = [ethTxSessionKeyAuth.address];
  const execution_strategies: string[] = [vanillaExecutionStrategy.address];

  const args = {
    public_key: controller.publicKey,
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: controller.starknetContract.address,
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    execution_strategies: execution_strategies,
  };

  console.log('Deploying space contract...');
  const space = await declareAndDeployContract('./contracts/starknet/SpaceAccount.cairo', args);

  return {
    space,
    controller,
    ethTxSessionKeyAuth,
    vanillaVotingStrategy,
    vanillaExecutionStrategy,
    mockStarknetMessaging,
    starknetCommit,
  };
}

export async function ethBalanceOfSetup(block: any, proofs: any) {
  // We pass the encode params function for the single slot proof strategy to generate the encoded data for the single slot proof strategy
  const proofInputs: utils.storageProofs.ProofInputs = utils.storageProofs.getProofInputs(
    block.number,
    proofs
  );

  const controller = await getAccount(1);

  const fossil = await fossilSetup(controller);

  const vanillaAuthenticator = await declareAndDeployContract(
    './contracts/starknet/Authenticators/Vanilla.cairo'
  );
  const ethBalanceOfVotingStrategy = await declareAndDeployContract(
    'contracts/starknet/VotingStrategies/EthBalanceOf.cairo',
    {
      fact_registry_address: BigInt(fossil.factsRegistry.address),
      l1_headers_store_address: BigInt(fossil.l1HeadersStore.address),
    }
  );
  const vanillaExecutionStrategy = await declareAndDeployContract(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

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
  const votingStrategies: string[] = [ethBalanceOfVotingStrategy.address];
  const votingStrategyParams: string[][] = [[proofInputs.ethAddressFelt, '0x0']]; // For the aave erc20 contract, the balances mapping has a storage index of 0
  const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: string[] = [vanillaAuthenticator.address];
  const execution_strategies: string[] = [vanillaExecutionStrategy.address];
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  // Deploy space with specified parameters
  const args = {
    public_key: controller.publicKey,
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: controllerAddress,
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    execution_strategies: execution_strategies,
  };

  console.log('Deploying space contract...');
  const space = await declareAndDeployContract('./contracts/starknet/SpaceAccount.cairo', args);

  return {
    space,
    controller,
    vanillaAuthenticator,
    ethBalanceOfVotingStrategy,
    vanillaExecutionStrategy,
    fossil,
    proofInputs,
  };
}

// Setup function to test the single slot proof strategy in isolation, ie not within context of space contract
export async function singleSlotProofSetupIsolated(block: any) {
  const account = await getAccount(1);
  const fossil = await fossilSetup(account);
  const singleSlotProofStrategy = await declareAndDeployContract(
    'contracts/starknet/VotingStrategies/SingleSlotProof.cairo',
    {
      fact_registry_address: BigInt(fossil.factsRegistry.address),
      l1_headers_store_address: BigInt(fossil.l1HeadersStore.address),
    }
  );

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
  const factsRegistry = await declareAndDeployContract(
    'fossil/contracts/starknet/FactsRegistry.cairo'
  );
  const l1HeadersStore = await declareAndDeployContract(
    'fossil/contracts/starknet/L1HeadersStore.cairo'
  );
  const l1RelayerAccount = await getAccount(2);

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

export async function starkSigAuthSetup() {
  const controller = await getAccount(1);

  const starkSigAuth = await declareAndDeployContract(
    './contracts/starknet/Authenticators/StarkSig.cairo'
  );
  const vanillaVotingStrategy = await declareAndDeployContract(
    'contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const vanillaExecutionStrategy = await declareAndDeployContract(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: string[] = [vanillaVotingStrategy.address];
  const votingStrategyParams: string[][] = [[]]; // No params for the vanilla voting strategy
  const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: string[] = [starkSigAuth.address];
  const execution_strategies: string[] = [vanillaExecutionStrategy.address];
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  const args = {
    public_key: controller.publicKey,
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: controller.starknetContract.address,
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    execution_strategies: execution_strategies,
  };

  const space = await declareAndDeployContract('./contracts/starknet/SpaceAccount.cairo', args);

  return {
    space,
    starkSigAuth,
    vanillaVotingStrategy,
    vanillaExecutionStrategy,
    controller,
  };
}

export async function starkTxAuthSetup() {
  const controller = await getAccount(1);

  const starknetTxAuthenticator = await declareAndDeployContract(
    './contracts/starknet/Authenticators/StarkTx.cairo'
  );
  const vanillaVotingStrategy = await declareAndDeployContract(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const vanillaExecutionStrategy = await declareAndDeployContract(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: string[] = [vanillaVotingStrategy.address];
  const votingStrategyParams: string[][] = [[]]; // No params for the vanilla voting strategy
  const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: string[] = [starknetTxAuthenticator.address];
  const execution_strategies: string[] = [vanillaExecutionStrategy.address];
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  console.log('Deploying space contract...');
  const args = {
    public_key: controller.publicKey,
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: controller.starknetContract.address,
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    execution_strategies: execution_strategies,
  };

  console.log('Deploying space contract...');
  const space = await declareAndDeployContract('./contracts/starknet/SpaceAccount.cairo', args);
  console.log('deployed!');

  return {
    space,
    controller,
    starknetTxAuthenticator,
    vanillaVotingStrategy,
    vanillaExecutionStrategy,
  };
}

export async function ethSigAuthSetup() {
  const controller = await getAccount(1);

  const ethSigAuth = await declareAndDeployContract(
    './contracts/starknet/Authenticators/EthSig.cairo'
  );
  const vanillaVotingStrategy = await declareAndDeployContract(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const vanillaExecutionStrategy = await declareAndDeployContract(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: string[] = [vanillaVotingStrategy.address];
  const votingStrategyParams: string[][] = [[]]; // No params for the vanilla voting strategy
  const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: string[] = [ethSigAuth.address];
  const execution_strategies: string[] = [vanillaExecutionStrategy.address];
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  const args = {
    public_key: controller.publicKey,
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: controller.starknetContract.address,
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    execution_strategies: execution_strategies,
  };

  console.log('Deploying space contract...');
  const space = await declareAndDeployContract('./contracts/starknet/SpaceAccount.cairo', args);
  return {
    space,
    controller,
    ethSigAuth,
    vanillaVotingStrategy,
    vanillaExecutionStrategy,
  };
}

export async function starknetSigAuthSetup() {
  const controller = await getAccount(1);

  const starkSigAuth = await declareAndDeployContract(
    './contracts/starknet/Authenticators/StarkSig.cairo'
  );
  const vanillaVotingStrategy = await declareAndDeployContract(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const vanillaExecutionStrategy = await declareAndDeployContract(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: string[] = [vanillaVotingStrategy.address];
  const votingStrategyParams: string[][] = [[]]; // No params for the vanilla voting strategy
  const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: string[] = [starkSigAuth.address];
  const execution_strategies: string[] = [vanillaExecutionStrategy.address];
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  const args = {
    public_key: controller.publicKey,
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: controller.starknetContract.address,
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    execution_strategies: execution_strategies,
  };

  console.log('Deploying space contract...');
  const space = await declareAndDeployContract('./contracts/starknet/SpaceAccount.cairo', args);

  return {
    space,
    controller,
    starkSigAuth,
    vanillaVotingStrategy,
    vanillaExecutionStrategy,
  };
}

export async function spaceFactorySetup() {
  const controller = await getAccount(1);

  const spaceFactoryClass = await starknet.getContractFactory(
    './contracts/starknet/SpaceAccount.cairo'
  );
  const spaceHash = await controller.declare(spaceFactoryClass);

  const vanillaAuthenticator = await declareAndDeployContract(
    './contracts/starknet/Authenticators/Vanilla.cairo'
  );
  const vanillaVotingStrategy = await declareAndDeployContract(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const vanillaExecutionStrategy = await declareAndDeployContract(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );
  const spaceDeployer = await declareAndDeployContract('./contracts/starknet/SpaceFactory.cairo', {
    space_class_hash: spaceHash,
  });

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
  const controller = await getAccount(1);

  const vanillaAuthenticator = await declareAndDeployContract(
    './contracts/starknet/Authenticators/Vanilla.cairo'
  );
  const vanillaVotingStrategy = await declareAndDeployContract(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const starknetExecutionStrategy = await declareAndDeployContract(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: string[] = [vanillaVotingStrategy.address];
  const votingStrategyParams: string[][] = [[]]; // No params for the vanilla voting strategy
  const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: string[] = [vanillaAuthenticator.address];
  const execution_strategies: string[] = ['0x1', '0x1234', '0x4567', '0x456789']; // We add dummy execution_strategies that get used in the test transactions
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  const args = {
    public_key: controller.publicKey,
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: controller.starknetContract.address,
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    execution_strategies: execution_strategies,
  };

  console.log('Deploying space contract...');
  const space = await declareAndDeployContract('./contracts/starknet/SpaceAccount.cairo', args);

  return {
    space,
    controller,
    vanillaAuthenticator,
    vanillaVotingStrategy,
    starknetExecutionStrategy,
  };
}

export async function ethSigSessionKeyAuthSetup() {
  const controller = await getAccount(1);

  const ethSigSessionKeyAuth = await declareAndDeployContract(
    './contracts/starknet/Authenticators/EthSigSessionKey.cairo'
  );
  const vanillaVotingStrategy = await declareAndDeployContract(
    './contracts/starknet/VotingStrategies/Vanilla.cairo'
  );
  const vanillaExecutionStrategy = await declareAndDeployContract(
    './contracts/starknet/ExecutionStrategies/Vanilla.cairo'
  );

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: string[] = [vanillaVotingStrategy.address];
  const votingStrategyParams: string[][] = [[]]; // No params for the vanilla voting strategy
  const votingStrategyParamsFlat: string[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: string[] = [ethSigSessionKeyAuth.address];
  const execution_strategies: string[] = [vanillaExecutionStrategy.address];
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test

  const args = {
    public_key: controller.publicKey,
    voting_delay: votingDelay,
    min_voting_duration: minVotingDuration,
    max_voting_duration: maxVotingDuration,
    proposal_threshold: proposalThreshold,
    controller: controller.starknetContract.address,
    quorum: quorum,
    voting_strategy_params_flat: votingStrategyParamsFlat,
    voting_strategies: votingStrategies,
    authenticators: authenticators,
    execution_strategies: execution_strategies,
  };

  console.log('Deploying space contract...');
  const space = await declareAndDeployContract('./contracts/starknet/SpaceAccount.cairo', args);

  return {
    space,
    controller,
    ethSigSessionKeyAuth,
    vanillaVotingStrategy,
    vanillaExecutionStrategy,
  };
}
