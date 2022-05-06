import { stark } from 'starknet';
import { SplitUint256, FOR } from './shared/types';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { expect } from 'chai';
import { starknet } from 'hardhat';
import { VITALIK_ADDRESS } from './shared/setup';
import { StarknetContract } from 'hardhat/types';

const { getSelectorFromName } = stark;

describe('Whitelist testing', () => {
  let whitelistStrat: StarknetContract;
  let emptyStrat: StarknetContract;
  let repeatStrat: StarknetContract;
  let bigStrat: StarknetContract;
  const ADDRR_1 = BigInt('11111');
  const ADDRR_2 = BigInt('22222');
  const ADDRR_3 = BigInt('33333');
  const ADDRR_4 = BigInt('44444');

  const VITALIK_POWER = SplitUint256.fromUint(BigInt('1000'));
  const ADDRR_1_POWER = SplitUint256.fromUint(BigInt('1'));
  const ADDRR_2_POWER = SplitUint256.fromUint(BigInt('2'));
  const ADDRR_3_POWER = SplitUint256.fromUint(BigInt('3'));
  const ADDRR_4_POWER = SplitUint256.fromUint(BigInt('4'));

  before(async function () {
    this.timeout(800000);

    const whitelistFactory = await starknet.getContractFactory(
      './contracts/starknet/voting_strategies/whitelist.cairo'
    );
    whitelistStrat = await whitelistFactory.deploy({
      _whitelist: [VITALIK_ADDRESS, VITALIK_POWER.low, VITALIK_POWER.high],
    });
    emptyStrat = await whitelistFactory.deploy({ _whitelist: [] });
    repeatStrat = await whitelistFactory.deploy({
      _whitelist: [
        VITALIK_ADDRESS,
        VITALIK_POWER.low,
        VITALIK_POWER.high,
        VITALIK_ADDRESS,
        VITALIK_POWER.low,
        VITALIK_POWER.high,
        ADDRR_1,
        ADDRR_1_POWER.low,
        ADDRR_1_POWER.high,
      ],
    });
    bigStrat = await whitelistFactory.deploy({
      _whitelist: [
        ADDRR_1,
        ADDRR_1_POWER.low,
        ADDRR_1_POWER.high,
        ADDRR_2,
        ADDRR_2_POWER.low,
        ADDRR_2_POWER.high,
        ADDRR_3,
        ADDRR_3_POWER.low,
        ADDRR_3_POWER.high,
        ADDRR_4,
        ADDRR_4_POWER.low,
        ADDRR_4_POWER.high,
      ],
    });
  });

  it('returns 0 for non-whitelisted addresses', async () => {
    const random_address = BigInt(0x12345);
    const { voting_power } = await whitelistStrat.call('get_voting_power', {
      timestamp: BigInt(0),
      address: { value: random_address },
      params: [],
    });

    const vp = SplitUint256.fromObj(voting_power);
    const expected = SplitUint256.fromUint(BigInt(0));
    expect(vp).to.deep.equal(expected);
  }).timeout(80000);

  it('returns voting power for whitelisted addresses', async () => {
    const random_address = BigInt(0x12345);
    const { voting_power } = await whitelistStrat.call('get_voting_power', {
      timestamp: BigInt(0),
      address: { value: VITALIK_ADDRESS },
      params: [],
    });

    const vp = SplitUint256.fromObj(voting_power);
    const expected = VITALIK_POWER;
    expect(vp).to.deep.equal(expected);
  }).timeout(80000);

  it('returns 0 for an empty whitelist', async () => {
    const { voting_power } = await emptyStrat.call('get_voting_power', {
      timestamp: BigInt(0),
      address: { value: VITALIK_ADDRESS },
      params: [],
    });

    const vp = SplitUint256.fromObj(voting_power);
    const expected = SplitUint256.fromUint(BigInt(0));
    expect(vp).to.deep.equal(expected);
  }).timeout(80000);

  it('returns the voting power even if address is repeated', async () => {
    const { voting_power } = await repeatStrat.call('get_voting_power', {
      timestamp: BigInt(0),
      address: { value: VITALIK_ADDRESS },
      params: [],
    });

    const vp = SplitUint256.fromObj(voting_power);
    const expected = VITALIK_POWER;
    expect(vp).to.deep.equal(expected);
  }).timeout(80000);

  it('returns the voting power if address is NOT repeated', async () => {
    const { voting_power } = await bigStrat.call('get_voting_power', {
      timestamp: BigInt(0),
      address: { value: ADDRR_1 },
      params: [],
    });

    const vp = SplitUint256.fromObj(voting_power);
    const expected = ADDRR_1_POWER;
    expect(vp).to.deep.equal(expected);
  }).timeout(80000);

  it('returns the voting power for everyone in the list', async () => {
    const voting_power1 = await bigStrat.call('get_voting_power', {
      timestamp: BigInt(0),
      address: { value: ADDRR_1 },
      params: [],
    });
    const voting_power2 = await bigStrat.call('get_voting_power', {
      timestamp: BigInt(0),
      address: { value: ADDRR_2 },
      params: [],
    });
    const voting_power3 = await bigStrat.call('get_voting_power', {
      timestamp: BigInt(0),
      address: { value: ADDRR_3 },
      params: [],
    });
    const voting_power4 = await bigStrat.call('get_voting_power', {
      timestamp: BigInt(0),
      address: { value: ADDRR_4 },
      params: [],
    });

    const results = [voting_power1, voting_power2, voting_power3, voting_power4];
    const expected_power = [ADDRR_1_POWER, ADDRR_2_POWER, ADDRR_3_POWER, ADDRR_4_POWER];
    results.forEach(function ({ voting_power }, index) {
      const vp = SplitUint256.fromObj(voting_power);
      const expected = expected_power[index];
      expect(vp).to.deep.equal(expected);
    });
  }).timeout(80000);

  it('returns 0 if address is NOT in the big list', async () => {
    const { voting_power } = await bigStrat.call('get_voting_power', {
      timestamp: BigInt(0),
      address: { value: VITALIK_ADDRESS },
      params: [],
    });

    const vp = SplitUint256.fromObj(voting_power);
    const expected = SplitUint256.fromUint(BigInt(0));
    expect(vp).to.deep.equal(expected);
  }).timeout(80000);
}).timeout(600000);
