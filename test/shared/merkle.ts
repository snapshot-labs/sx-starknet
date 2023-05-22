import { pedersen } from 'starknet/dist/utils/hash';

export class MerkleTree {
  root: string;
  constructor(values: string[]) {
    this.root = MerkleTree.generateMerkleRoot(values);
  }

  getProof(values: string[], index: number): string[] {
    return MerkleTree.getProofHelper(values, index, []);
  }

  static generateMerkleRoot(values: string[]): string {
    if (values.length == 1) {
      return values[0];
    }
    if (values.length % 2 != 0) {
      values.push('0x0');
    }
    const nextLevel = MerkleTree.getNextLevel(values);
    return MerkleTree.generateMerkleRoot(nextLevel);
  }

  static getNextLevel(level: string[]): string[] {
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

  static getProofHelper(level: string[], index: number, proof: string[]): string[] {
    if (level.length == 1) {
      return proof;
    }
    if (level.length % 2 != 0) {
      level.push('0x0');
    }
    const nextLevel = MerkleTree.getNextLevel(level);
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
    return MerkleTree.getProofHelper(nextLevel, indexParent, proof);
  }
}
