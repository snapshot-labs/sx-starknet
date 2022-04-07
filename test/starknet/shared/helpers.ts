import { starknet } from 'hardhat';
import { SplitUint256 } from './types';
import { StarknetContract } from 'hardhat/types';
import { expect } from 'chai';

export const EXECUTE_METHOD = 'execute';
export const PROPOSAL_METHOD = 'propose';
export const VOTE_METHOD = 'vote';
export const GET_PROPOSAL_INFO = 'get_proposal_info';
export const GET_VOTE_INFO = 'get_vote_info';
export const VOTING_DELAY = BigInt(0);
export const VOTING_PERIOD = BigInt(20);
export const VITALIK_ADDRESS = BigInt(0xd8da6bf26964af9d7eed9e03e53415d37aa96045);
export const VITALIK_STRING_ADDRESS = '0xd8da6bf26964af9d7eed9e03e53415d37aa96045';

export function assert(condition: boolean, message = 'Assertion Failed'): boolean {
  if (!condition) {
    throw message;
  }
  return condition;
}

export function hexToBytes(hex: string): number[] {
  const bytes = [];
  for (let c = 2; c < hex.length; c += 2) bytes.push(parseInt(hex.substring(c, c + 2), 16));
  return bytes;
}

export function bytesToHex(bytes: number[]): string {
  const body = Array.from(bytes, function (byte) {
    return ('0' + (byte & 0xff).toString(16)).slice(-2);
  }).join('');
  return '0x' + body;
}

export async function setup() {
  const vanillaSpaceFactory = await starknet.getContractFactory(
    './contracts/starknet/space/space.cairo'
  );
  const vanillaVotingStategyFactory = await starknet.getContractFactory(
    './contracts/starknet/strategies/vanilla_voting_strategy.cairo'
  );
  const vanillaAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/authenticator/authenticator.cairo'
  );
  const zodiacRelayerFactory = await starknet.getContractFactory(
    './contracts/starknet/execution/zodiac_l1.cairo'
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
    _voting_period: VOTING_PERIOD,
    _proposal_threshold: PROPOSAL_THRESHOLD,
    _voting_strategy: voting_strategy,
    _authenticator: authenticator,
    _executor: zodiac_relayer,
  })) as StarknetContract;
  console.log('deployed!');

  return {
    vanillaSpace,
    vanillaAuthenticator,
    vanillaVotingStrategy,
    zodiacRelayer,
  };
}

/**
 * Receives a hex address, converts it to bigint, converts it back to hex.
 * This is done to strip leading zeros.
 * @param address a hex string representation of an address
 * @returns an adapted hex string representation of the address
 */
export function adaptAddress(address: string) {
  return '0x' + BigInt(address).toString(16);
}

/**
 * Expects address equality after adapting them.
 * @param actual
 * @param expected
 */
export function expectAddressEquality(actual: string, expected: string) {
  expect(adaptAddress(actual)).to.equal(adaptAddress(expected));
}
