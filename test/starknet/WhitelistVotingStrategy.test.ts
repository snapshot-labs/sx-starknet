import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { StarknetContract } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';

describe('Whitelist testing', () => {
  let whitelist: StarknetContract;
  let emptyWhitelist: StarknetContract;
  let repeatWhitelist: StarknetContract;

  let address1: string;
  let address2: string;
  let address3: string;
  let address4: string;

  let power1: utils.splitUint256.SplitUint256;
  let power2: utils.splitUint256.SplitUint256;
  let power3: utils.splitUint256.SplitUint256;
  let power4: utils.splitUint256.SplitUint256;

  before(async function () {
    this.timeout(800000);
    address1 = ethers.Wallet.createRandom().address;
    address2 = ethers.Wallet.createRandom().address;
    address3 = ethers.Wallet.createRandom().address;
    address4 = ethers.Wallet.createRandom().address;

    power1 = utils.splitUint256.SplitUint256.fromUint(BigInt('1000'));
    power2 = utils.splitUint256.SplitUint256.fromUint(BigInt('1'));
    power3 = utils.splitUint256.SplitUint256.fromUint(BigInt('2'));
    power4 = utils.splitUint256.SplitUint256.fromUint(BigInt('3'));

    const whitelistFactory = await starknet.getContractFactory(
      './contracts/starknet/VotingStrategies/Whitelist.cairo'
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
      timestamp: BigInt(0),
      voter_address: { value: address1 },
      params: [],
      user_params: [],
    });
    const { voting_power: vp2 } = await whitelist.call('get_voting_power', {
      timestamp: BigInt(0),
      voter_address: { value: address2 },
      params: [],
      user_params: [],
    });
    const { voting_power: vp3 } = await whitelist.call('get_voting_power', {
      timestamp: BigInt(0),
      voter_address: { value: address3 },
      params: [],
      user_params: [],
    });
    const { voting_power: vp4 } = await whitelist.call('get_voting_power', {
      timestamp: BigInt(0),
      voter_address: { value: address4 },
      params: [],
      user_params: [],
    });
    expect(
      new utils.splitUint256.SplitUint256(`0x${vp1.low.toString(16)}`, `0x${vp1.high.toString(16)}`)
    ).to.deep.equal(power1);
    expect(
      new utils.splitUint256.SplitUint256(`0x${vp2.low.toString(16)}`, `0x${vp2.high.toString(16)}`)
    ).to.deep.equal(power2);
    expect(
      new utils.splitUint256.SplitUint256(`0x${vp3.low.toString(16)}`, `0x${vp3.high.toString(16)}`)
    ).to.deep.equal(power3);
    expect(
      new utils.splitUint256.SplitUint256(`0x${vp4.low.toString(16)}`, `0x${vp4.high.toString(16)}`)
    ).to.deep.equal(power4);
  }).timeout(1000000);

  it('returns 0 voting power for non-whitelisted addresses', async () => {
    const { voting_power: vp } = await whitelist.call('get_voting_power', {
      timestamp: BigInt(0),
      voter_address: { value: BigInt(ethers.Wallet.createRandom().address) },
      params: [],
      user_params: [],
    });
    expect(
      new utils.splitUint256.SplitUint256(`0x${vp.low.toString(16)}`, `0x${vp.high.toString(16)}`)
    ).to.deep.equal(utils.splitUint256.SplitUint256.fromUint(BigInt(0)));
  }).timeout(1000000);

  it('returns 0 for an empty whitelist', async () => {
    const { voting_power: vp } = await emptyWhitelist.call('get_voting_power', {
      timestamp: BigInt(0),
      voter_address: { value: address1 },
      params: [],
      user_params: [],
    });
    expect(
      new utils.splitUint256.SplitUint256(`0x${vp.low.toString(16)}`, `0x${vp.high.toString(16)}`)
    ).to.deep.equal(utils.splitUint256.SplitUint256.fromUint(BigInt(0)));
  }).timeout(1000000);

  it('returns the correct voting power even if address is repeated', async () => {
    const { voting_power: vp } = await repeatWhitelist.call('get_voting_power', {
      timestamp: BigInt(0),
      voter_address: { value: address1 },
      params: [],
      user_params: [],
    });
    expect(
      new utils.splitUint256.SplitUint256(`0x${vp.low.toString(16)}`, `0x${vp.high.toString(16)}`)
    ).to.deep.equal(power1);
  }).timeout(1000000);
});
