import { StarknetContract } from 'hardhat/types/runtime';
import { expect } from 'chai';
import { ethers, starknet } from 'hardhat';
import { computeHashOnElements } from 'starknet/dist/utils/hash';
import { MerkleTree } from '../shared/merkle';
import { declareAndDeployContract } from '../utils/deploy';

describe('Merkle:', () => {
  let testMerkle: StarknetContract;

  before(async function () {
    this.timeout(800000);
    testMerkle = await declareAndDeployContract(
      './contracts/starknet/TestContracts/Test_Merkle.cairo'
    );
  });

  it('The library should handle a tree with one leaf', async () => {
    const values = [];
    // Generating random data for the merkle tree
    for (let i = 0; i < 1; i++) {
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
    const tree = new MerkleTree(leaves);
    // Picking random leaf to prove
    const address = values[Math.floor(Math.random() * 1)][0];
    const leafData = merkleData.find((leaf) => leaf[1] == address)!;

    await testMerkle.call('testAssertValidLeaf', {
      root: tree.root,
      leaf: [leafData[1], leafData[2]],
      proof: tree.getProof(leaves, Number(leafData[3])),
    });

    it('The library should handle a tree with two leaves', async () => {
      const values = [];
      // Generating random data for the merkle tree
      for (let i = 0; i < 2; i++) {
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
      const tree = new MerkleTree(leaves);
      // Picking random leaf to prove
      const address = values[Math.floor(Math.random() * 2)][0];
      const leafData = merkleData.find((leaf) => leaf[1] == address)!;

      await testMerkle.call('testAssertValidLeaf', {
        root: tree.root,
        leaf: [leafData[1], leafData[2]],
        proof: tree.getProof(leaves, Number(leafData[3])),
      });
    });

    it('The library should verify a merkle proof for a leaf in a large tree', async () => {
      const values = [];
      // Generating random data for the merkle tree
      for (let i = 0; i < 1000; i++) {
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
      const tree = new MerkleTree(leaves);

      // Picking random leaf to prove
      const address = values[Math.floor(Math.random() * 99)][0];
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
      const tree = new MerkleTree(leaves);

      // Picking random leaf to prove
      const address = values[Math.floor(Math.random() * 99)][0];
      const leafData = merkleData.find((leaf) => leaf[1] == address)!;

      const corruptedProof = tree.getProof(leaves, Number(leafData[3]));
      corruptedProof[0] = ethers.utils.hexlify(ethers.utils.randomBytes(4));
      try {
        await testMerkle.call('testAssertValidLeaf', {
          root: tree.root,
          leaf: [leafData[1], leafData[2]],
          proof: corruptedProof,
        });
        throw { message: 'invalid leaf asserted to be valid' };
      } catch (error: any) {
        expect(error.message).to.contain('Merkle: Invalid proof');
      }
    }).timeout(600000);

    it('The library should handle a tree with no leaves', async () => {
      try {
        await testMerkle.call('testAssertValidLeaf', {
          root: '0x0',
          leaf: ['0x0', '0x0'],
          proof: '0x0',
        });
        throw { message: 'invalid leaf asserted to be valid' };
      } catch (error: any) {
        expect(error.message).to.contain('Merkle: Invalid proof');
      }
    });
  }).timeout(600000);
});
