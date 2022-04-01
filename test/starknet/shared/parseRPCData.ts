/* eslint-disable  @typescript-eslint/ban-types */

import Common, { Chain, Hardfork } from '@ethereumjs/common';
import { bufferToHex } from 'ethereumjs-util';
import blockFromRpc from '@ethereumjs/block/dist/from-rpc';
import { IntsSequence } from './types';
import { hexToBytes } from './helpers';

export class ProcessBlockInputs {
  blockNumber: number;
  blockOptions: number;
  headerInts: IntsSequence;

  constructor(blockNumber: number, blockOptions: number, headerInts: IntsSequence) {
    this.blockNumber = blockNumber;
    this.blockOptions = blockOptions;
    this.headerInts = headerInts;
  }

  static fromBlockRPCData(
    block: any,
    _chain: Chain = Chain.Mainnet,
    _hardfork: Hardfork = Hardfork.London
  ): ProcessBlockInputs {
    block.difficulty = '0x' + BigInt(block.difficulty).toString(16);
    block.totalDifficulty = '0x' + BigInt(block.totalDifficulty).toString(16);
    const common = new Common({ chain: _chain, hardfork: _hardfork });
    const header = blockFromRpc(block, [], { common }).header;
    const headerRlp = bufferToHex(header.serialize());
    const headerInts = IntsSequence.fromBytes(hexToBytes(headerRlp));
    return new ProcessBlockInputs(block.number, 8, headerInts);
  }
}

export class ProofInputs {
  blockNumber: number;
  accountOptions: number;
  ethAddress: IntsSequence;
  ethAddressFelt: bigint; //Fossil treats eth addresses two different ways for some reason, it will be changed soon but now this works
  accountProofSizesBytes: bigint[];
  accountProofSizesWords: bigint[];
  accountProof: bigint[];
  votingPowerParams: bigint[];

  constructor(
    blockNumber: number,
    accountOptions: number,
    ethAddress: IntsSequence,
    ethAddressFelt: bigint,
    accountProofSizesBytes: bigint[],
    accountProofSizesWords: bigint[],
    accountProof: bigint[],
    votingPowerParams: bigint[]
  ) {
    this.blockNumber = blockNumber;
    this.accountOptions = accountOptions;
    this.ethAddress = ethAddress;
    this.ethAddressFelt = ethAddressFelt;
    this.accountProofSizesBytes = accountProofSizesBytes;
    this.accountProofSizesWords = accountProofSizesWords;
    this.accountProof = accountProof;
    this.votingPowerParams = votingPowerParams;
  }

  static fromProofRPCData(blockNumber: number, proofs: any, encodeParams: Function): ProofInputs {
    const accountProofArray = proofs.accountProof.map((node: string) =>
      IntsSequence.fromBytes(hexToBytes(node))
    );
    let accountProof: bigint[] = [];
    let accountProofSizesBytes: bigint[] = [];
    let accountProofSizesWords: bigint[] = [];
    for (const node of accountProofArray) {
      accountProof = accountProof.concat(node.values);
      accountProofSizesBytes = accountProofSizesBytes.concat([BigInt(node.bytesLength)]);
      accountProofSizesWords = accountProofSizesWords.concat([BigInt(node.values.length)]);
    }
    const ethAddress = IntsSequence.fromBytes(hexToBytes(proofs.address));
    const ethAddressFelt = BigInt(proofs.address);
    const slot = IntsSequence.fromBytes(hexToBytes(proofs.storageProof[0].key));
    const storageProofArray = proofs.storageProof[0].proof.map((node: string) =>
      IntsSequence.fromBytes(hexToBytes(node))
    );
    let storageProof: bigint[] = [];
    let storageProofSizesBytes: bigint[] = [];
    let storageProofSizesWords: bigint[] = [];
    for (const node of storageProofArray) {
      storageProof = storageProof.concat(node.values);
      storageProofSizesBytes = storageProofSizesBytes.concat([BigInt(node.bytesLength)]);
      storageProofSizesWords = storageProofSizesWords.concat([BigInt(node.values.length)]);
    }
    const votingPowerParams = encodeParams(
      slot.values,
      storageProofSizesBytes,
      storageProofSizesWords,
      storageProof
    );
    return new ProofInputs(
      blockNumber,
      15,
      ethAddress,
      ethAddressFelt,
      accountProofSizesBytes,
      accountProofSizesWords,
      accountProof,
      votingPowerParams
    );
  }
}
