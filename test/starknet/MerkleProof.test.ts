import { StarknetContract } from 'hardhat/types/runtime';
import { expect } from 'chai';
import { ethers, starknet } from 'hardhat';
import { computeHashOnElements, pedersen } from 'starknet/dist/utils/hash';

class Merkle {
  root: string;
  constructor(values: string[]) {
    this.root = generateMerkleRoot(values);
  }

  getProof(values: string[], index: number): string[] {
    return getProofHelper(values, index, []);
  }
}

function generateMerkleRoot(values: string[]): string {
  if (values.length == 1) {
    return values[0];
  }
  if (values.length % 2 != 0) {
    values.push('0x0');
  }
  const nextLevel = getNextLevel(values);
  return generateMerkleRoot(nextLevel);
}

function getNextLevel(level: string[]): string[] {
  const nextLevel = [];
  for (let i = 0; i < level.length; i += 2) {
    let node = '0x0';
    if (BigInt(level[i]) < BigInt(level[i + 1])) {
      node = pedersen([level[i], level[i + 1]]);
    } else {
      node = pedersen([level[i + 1], level[i]]);
    }
    nextLevel.push(node);
  }
  return nextLevel;
}

function getProofHelper(level: string[], index: number, proof: string[]): string[] {
  if (level.length == 1) {
    return proof;
  }
  if (level.length % 2 != 0) {
    level.push('0x0');
  }
  const nextLevel = getNextLevel(level);
  let indexParent = 0;

  for (let i = 0; i < level.length; i++) {
    if (i == index) {
      indexParent = Math.floor(i / 2);
      if (i % 2 == 0) {
        proof.push(level[index + 1]);
      } else {
        proof.push(level[index - 1]);
      }
    }
  }
  return getProofHelper(nextLevel, indexParent, proof);
}

describe('Merkle:', () => {
  let testMerkle: StarknetContract;

  before(async function () {
    this.timeout(800000);
    const testMerkleFactory = await starknet.getContractFactory(
      './contracts/starknet/TestContracts/Test_Merkle.cairo'
    );
    testMerkle = await testMerkleFactory.deploy();
  });

  it('The library should verify a merkle proof for a given root', async () => {
    const values = [];
    // Generating random data for the merkle tree
    for (let i = 0; i < 100; i++) {
      values.push([
        ethers.Wallet.createRandom().address,
        ethers.utils.hexlify(ethers.utils.randomBytes(1)),
      ]);
    }

    // computing the hash of each address value pair, and sorting
    const merkleData = values
      .map((v, i) => [computeHashOnElements(v), v[0], v[1]])
      .sort(function (a, b) {
        if (a > b) return 1;
        if (a < b) return -1;
        return 0;
      })
      .map((x, i) => [x[0], x[1], x[2], i]);
    const leaves = merkleData.map((x) => x[0].toString());
    const tree = new Merkle(leaves);

    // Picking random leaf to prove
    const address = values[17][0];
    const leafData = merkleData.find((leaf) => leaf[1] == address)!;

    await testMerkle.call('testAssertValidLeaf', {
      root: tree.root,
      leaf: [leafData[1], leafData[2]],
      proof: tree.getProof(leaves, Number(leafData[3])),
    });
  }).timeout(600000);

  it('The library should fail to verify if an invalid proof is supplied', async () => {
    const values = [];
    // Generating random data for the merkle tree
    for (let i = 0; i < 100; i++) {
      values.push([
        ethers.Wallet.createRandom().address,
        ethers.utils.hexlify(ethers.utils.randomBytes(1)),
      ]);
    }

    // computing the hash of each address value pair, and sorting
    const merkleData = values
      .map((v, i) => [computeHashOnElements(v), v[0], v[1]])
      .sort(function (a, b) {
        if (a > b) return 1;
        if (a < b) return -1;
        return 0;
      })
      .map((x, i) => [x[0], x[1], x[2], i]);
    const leaves = merkleData.map((x) => x[0].toString());
    const tree = new Merkle(leaves);

    // Picking random leaf to prove
    const address = values[27][0];
    const leafData = merkleData.find((leaf) => leaf[1] == address)!;

    const corruptedProof = tree.getProof(leaves, Number(leafData[3]));
    corruptedProof[0] = ethers.utils.hexlify(ethers.utils.randomBytes(4));
    try {
      await testMerkle.call('testAssertValidLeaf', {
        root: tree.root,
        leaf: [leafData[1], leafData[2]],
        proof: corruptedProof,
      });
    } catch (error: any) {
      expect(error.message).to.contain('Merkle: Invalid proof');
    }
  }).timeout(600000);
});
