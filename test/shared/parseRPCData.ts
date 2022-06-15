/* eslint-disable  @typescript-eslint/ban-types */

import Common, { Chain, Hardfork } from '@ethereumjs/common';
import { bufferToHex } from 'ethereumjs-util';
import blockFromRpc from '@ethereumjs/block/dist/from-rpc';
import { IntsSequence } from './types';
import { hexToBytes } from './helpers';

export interface ProcessBlockInputs {
  blockNumber: number;
  blockOptions: number;
  headerInts: IntsSequence;
}

/**
 * Produces the inputs for the process_block function in Fossil.
 * @param block Block object from RPC call
 * @param _chain EVM chain identifier
 * @param _hardfork Hardfork identifier
 * @returns ProcessBlockInputs object
 */
export function getProcessBlockInputs(
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
  return {
    blockNumber: block.number as number,
    blockOptions: 8 as number,
    headerInts: headerInts as IntsSequence,
  };
}

export interface ProofInputs {
  blockNumber: number;
  accountOptions: number;
  ethAddress: IntsSequence;
  ethAddressFelt: bigint; // Fossil treats eth addresses two different ways for some reason, it will be changed soon but now this works
  accountProofSizesBytes: bigint[];
  accountProofSizesWords: bigint[];
  accountProof: bigint[];
  storageProofs: bigint[][]; // Multiple storage proofs
}

/**
 * Takes a proofs object obtained via a getStorageProof RPC call parses the data to extract the necessary data
 * and converts it to the correct form required by the SX/Fossil contracts.
 * @param blockNumber Number of the block that the proof targets
 * @param proofs Proofs object
 * @params encodeParams The encoding function that should be used on the storage proof data
 * @returns ProofInputs object
 */
export function getProofInputs(
  blockNumber: number,
  proofs: any,
  encodeParams: Function
): ProofInputs {
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

  const storageProofs = [];
  for (let i = 0; i < proofs.storageProof.length; i++) {
    const slot = IntsSequence.fromBytes(hexToBytes(proofs.storageProof[i].key));
    const storageProofArray = proofs.storageProof[i].proof.map((node: string) =>
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
    const storageProofEncoded = encodeParams(
      slot.values,
      storageProofSizesBytes,
      storageProofSizesWords,
      storageProof
    );
    storageProofs.push(storageProofEncoded);
  }

  return {
    blockNumber: blockNumber as number,
    accountOptions: 15 as number,
    ethAddress: ethAddress as IntsSequence,
    ethAddressFelt: ethAddressFelt as bigint,
    accountProofSizesBytes: accountProofSizesBytes as bigint[],
    accountProofSizesWords: accountProofSizesWords as bigint[],
    accountProof: accountProof as bigint[],
    storageProofs: storageProofs as bigint[][],
  };
}
