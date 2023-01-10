import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { StarknetContract } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { computeHashOnElements } from 'starknet/dist/utils/hash';
import { MerkleTree } from '../shared/merkle';
import { declareAndDeployContract } from '../utils/deploy';

describe('Merkle Whitelist testing', () => {
  let whitelist: StarknetContract;

  let address1: string;
  let address2: string;
  let address3: string;
  let address4: string;

  let power1: utils.splitUint256.SplitUint256;
  let power2: utils.splitUint256.SplitUint256;
  let power3: utils.splitUint256.SplitUint256;
  let power4: utils.splitUint256.SplitUint256;

  let tree: MerkleTree;
  let leaves: string[];
  let merkleData: (string | number)[][];

  before(async function () {
    this.timeout(800000);

    whitelist = await declareAndDeployContract(
      './contracts/starknet/VotingStrategies/MerkleWhitelist.cairo'
    );

    address1 = ethers.Wallet.createRandom().address;
    address2 = ethers.Wallet.createRandom().address;
    address3 = ethers.Wallet.createRandom().address;
    address4 = ethers.Wallet.createRandom().address;

    power1 = utils.splitUint256.SplitUint256.fromUint(BigInt('1000'));
    power2 = utils.splitUint256.SplitUint256.fromUint(BigInt('1'));
    power3 = utils.splitUint256.SplitUint256.fromUint(BigInt('2'));
    power4 = utils.splitUint256.SplitUint256.fromUint(BigInt('3'));

    const values = [
      [address1, power1.low, power1.high],
      [address2, power2.low, power2.high],
      [address3, power3.low, power3.high],
      [address4, power4.low, power4.high],
    ];

    // computing the hash of each address value pair, and sorting
    merkleData = values
      .map((v, i) => [computeHashOnElements(v), v[0], v[1]])
      .sort(function (a, b) {
        if (a > b) return 1;
        if (a < b) return -1;
        return 0;
      })
      .map((x, i) => [x[0], x[1], x[2], i]);
    leaves = merkleData.map((x) => x[0].toString());
    tree = new MerkleTree(leaves);
  });

  it('returns the voting power for everyone in the list', async () => {
    const leaf1 = merkleData.find((leaf) => leaf[1] == address1)!;
    const { voting_power: vp1 } = await whitelist.call('getVotingPower', {
      timestamp: BigInt(0),
      voter_address: { value: address1 },
      params: [tree.root],
      user_params: [address1, power1.low, power1.high, ...tree.getProof(leaves, Number(leaf1[3]))],
    });
    const leaf2 = merkleData.find((leaf) => leaf[1] == address2)!;
    const { voting_power: vp2 } = await whitelist.call('getVotingPower', {
      timestamp: BigInt(0),
      voter_address: { value: address2 },
      params: [tree.root],
      user_params: [address2, power2.low, power2.high, ...tree.getProof(leaves, Number(leaf2[3]))],
    });
    const leaf3 = merkleData.find((leaf) => leaf[1] == address3)!;
    const { voting_power: vp3 } = await whitelist.call('getVotingPower', {
      timestamp: BigInt(0),
      voter_address: { value: address3 },
      params: [tree.root],
      user_params: [address3, power3.low, power3.high, ...tree.getProof(leaves, Number(leaf3[3]))],
    });
    const leaf4 = merkleData.find((leaf) => leaf[1] == address4)!;
    const { voting_power: vp4 } = await whitelist.call('getVotingPower', {
      timestamp: BigInt(0),
      voter_address: { value: address4 },
      params: [tree.root],
      user_params: [address4, power4.low, power4.high, ...tree.getProof(leaves, Number(leaf4[3]))],
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

  it('Should fail if an invalid proof is supplied', async () => {
    const leaf1 = merkleData.find((leaf) => leaf[1] == address1)!;
    try {
      const { voting_power: vp } = await whitelist.call('getVotingPower', {
        timestamp: BigInt(0),
        voter_address: { value: address2 },
        params: [tree.root],
        user_params: [
          address1,
          power1.low,
          power1.high,
          ...tree.getProof(leaves, Number(leaf1[3])),
        ],
      });
      throw { message: 'voting power returned for invalid proof' };
    } catch (err: any) {
      expect(err.message).to.contain('MerkleWhitelist: Invalid proof supplied');
    }
  }).timeout(1000000);
});
