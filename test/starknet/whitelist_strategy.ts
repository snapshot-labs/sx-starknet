import { stark } from 'starknet';
import { SplitUint256, FOR } from '../shared/types';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { StarknetContract } from 'hardhat/types';

const { getSelectorFromName } = stark;

describe('Whitelist testing', () => {
  let whitelist: StarknetContract;
  let emptyWhitelist: StarknetContract;
  let repeatWhitelist: StarknetContract;

  let address1: bigint;
  let address2: bigint;
  let address3: bigint;
  let address4: bigint;

  let power1: SplitUint256;
  let power2: SplitUint256;
  let power3: SplitUint256;
  let power4: SplitUint256;

  before(async function () {
    this.timeout(800000);
    address1 = BigInt(ethers.Wallet.createRandom().address);
    address2 = BigInt(ethers.Wallet.createRandom().address);
    address3 = BigInt(ethers.Wallet.createRandom().address);
    address4 = BigInt(ethers.Wallet.createRandom().address);

    power1 = SplitUint256.fromUint(BigInt('1000'));
    power2 = SplitUint256.fromUint(BigInt('1'));
    power3 = SplitUint256.fromUint(BigInt('2'));
    power4 = SplitUint256.fromUint(BigInt('3'));

    const whitelistFactory = await starknet.getContractFactory(
      './contracts/starknet/voting_strategies/Whitelist.cairo'
    );
    whitelist = await whitelistFactory.deploy({
      _whitelist: [
        address1,
        power1.low,
        power1.high,
        address2,
        power2.low,
        power2.high,
        address3,
        power3.low,
        power3.high,
        address4,
        power4.low,
        power4.high,
      ],
    });
    emptyWhitelist = await whitelistFactory.deploy({ _whitelist: [] });
    repeatWhitelist = await whitelistFactory.deploy({
      _whitelist: [
        address1,
        power1.low,
        power1.high,
        address1,
        power1.low,
        power1.high,
        address2,
        power2.low,
        power2.high,
      ],
    });
  });

  it('returns the voting power for everyone in the list', async () => {
    const { voting_power: vp1 } = await whitelist.call('get_voting_power', {
      block: BigInt(0),
      voter_address: { value: address1 },
      params: [],
      user_params: [],
    });
    const { voting_power: vp2 } = await whitelist.call('get_voting_power', {
      block: BigInt(0),
      voter_address: { value: address2 },
      params: [],
      user_params: [],
    });
    const { voting_power: vp3 } = await whitelist.call('get_voting_power', {
      block: BigInt(0),
      voter_address: { value: address3 },
      params: [],
      user_params: [],
    });
    const { voting_power: vp4 } = await whitelist.call('get_voting_power', {
      block: BigInt(0),
      voter_address: { value: address4 },
      params: [],
      user_params: [],
    });
    expect(SplitUint256.fromObj(vp1)).to.deep.equal(power1);
    expect(SplitUint256.fromObj(vp2)).to.deep.equal(power2);
    expect(SplitUint256.fromObj(vp3)).to.deep.equal(power3);
    expect(SplitUint256.fromObj(vp4)).to.deep.equal(power4);
  }).timeout(1000000);

  it('returns 0 voting power for non-whitelisted addresses', async () => {
    const { voting_power: vp } = await whitelist.call('get_voting_power', {
      block: BigInt(0),
      voter_address: { value: BigInt(ethers.Wallet.createRandom().address) },
      params: [],
      user_params: [],
    });
    expect(SplitUint256.fromObj(vp)).to.deep.equal(SplitUint256.fromUint(BigInt(0)));
  }).timeout(1000000);

  it('returns 0 for an empty whitelist', async () => {
    const { voting_power: vp } = await emptyWhitelist.call('get_voting_power', {
      block: BigInt(0),
      voter_address: { value: address1 },
      params: [],
      user_params: [],
    });
    expect(SplitUint256.fromObj(vp)).to.deep.equal(SplitUint256.fromUint(BigInt(0)));
  }).timeout(1000000);

  it('returns the correct voting power even if address is repeated', async () => {
    const { voting_power: vp } = await repeatWhitelist.call('get_voting_power', {
      block: BigInt(0),
      voter_address: { value: address1 },
      params: [],
      user_params: [],
    });
    expect(SplitUint256.fromObj(vp)).to.deep.equal(power1);
  }).timeout(1000000);
});
