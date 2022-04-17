import { starknet, ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { SplitUint256 } from './types';
import { StarknetContract } from 'hardhat/types';
import { Contract, ContractFactory } from 'ethers';
export const EXECUTE_METHOD = 'execute';
export const PROPOSAL_METHOD = 'propose';
export const VOTE_METHOD = 'vote';
export const GET_PROPOSAL_INFO = 'get_proposal_info';
export const GET_VOTE_INFO = 'get_vote_info';
export const VOTING_DELAY = BigInt(0);
export const VOTING_DURATION = BigInt(20);
export const VITALIK_ADDRESS = BigInt(0xd8da6bf26964af9d7eed9e03e53415d37aa96045);
export const VITALIK_STRING_ADDRESS = VITALIK_ADDRESS.toString(16);
export const CONTROLLER = BigInt(1337);

export async function vanillaSetup() {
  const vanillaSpaceFactory = await starknet.getContractFactory(
    './contracts/starknet/space/space.cairo'
  );
  const vanillaVotingStategyFactory = await starknet.getContractFactory(
    './contracts/starknet/strategies/vanilla.cairo'
  );
  const vanillaAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/authenticator/vanilla.cairo'
  );
  const zodiacRelayerFactory = await starknet.getContractFactory(
    './contracts/starknet/execution/zodiac_relayer.cairo'
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
    _voting_duration: VOTING_DURATION,
    _proposal_threshold: PROPOSAL_THRESHOLD,
    _executor: zodiac_relayer,
    _controller: CONTROLLER,
    _voting_strategies: [voting_strategy],
    _authenticators: [authenticator],
  })) as StarknetContract;
  console.log('deployed!');

  return {
    vanillaSpace,
    vanillaAuthenticator,
    vanillaVotingStrategy,
    zodiacRelayer,
  };
}

export async function ethTxAuthSetup(signer: SignerWithAddress) {
  const SpaceFactory = await starknet.getContractFactory('./contracts/starknet/space/space.cairo');
  const vanillaVotingStategyFactory = await starknet.getContractFactory(
    './contracts/starknet/strategies/vanilla.cairo'
  );
  const EthTxAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/authenticator/eth_tx.cairo'
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
    _voting_duration: VOTING_DURATION,
    _proposal_threshold: PROPOSAL_THRESHOLD,
    _executor: 1,
    _controller: 1,
    _voting_strategies: [voting_strategy],
    _authenticators: [authenticator],
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
