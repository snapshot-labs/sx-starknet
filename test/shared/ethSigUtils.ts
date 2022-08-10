<<<<<<< HEAD
import { _TypedDataEncoder } from '@ethersproject/hash';
import { TypedDataDomain, TypedDataField } from '@ethersproject/abstract-signer';
import { utils } from '@snapshot-labs/sx';

export function getHash(
=======
import { ethers } from 'hardhat';
import { TypedDataDomain, TypedDataField } from '@ethersproject/abstract-signer';
import { _TypedDataEncoder } from '@ethersproject/hash';

function getHash(
>>>>>>> develop
  domain: TypedDataDomain,
  types: Record<string, TypedDataField[]>,
  message: Record<string, any>
) {
  const msgHash = _TypedDataEncoder.hash(domain, types, message);

  // Stub code to generate and print the type hash
<<<<<<< HEAD
  // const vote = "Vote(uint256 salt,bytes32 space,uint256 proposal,uint256 choice)";
  // let s = Buffer.from(vote);
  // let typeHash: string = keccak256(s);
  // console.log("typeHash: ", typeHash);

  return msgHash;
}

export function prefixWithZeroes(s: string) {
  // Remove prefix
  if (s.startsWith('0x')) {
    s = s.substring(2);
  }

  const numZeroes = 64 - s.length;
  return '0x' + '0'.repeat(numZeroes) + s;
}

export function hexPadRight(s: string) {
  // Remove prefix
  if (s.startsWith('0x')) {
    s = s.substring(2);
  }

  // Odd length, need to prefix with a 0
  if (s.length % 2 != 0) {
    s = '0' + s;
  }

  const numZeroes = 64 - s.length;
  return '0x' + s + '0'.repeat(numZeroes);
}

// Extracts and returns the `r, s, v` values from a `signature`.
// `r`, `s` are SplitUint256, `v` is a BigInt
export function getRSVFromSig(sig: string) {
  if (sig.startsWith('0x')) {
    sig = sig.substring(2);
  }
  const r = utils.splitUint256.SplitUint256.fromHex('0x' + sig.substring(0, 64));
  const s = utils.splitUint256.SplitUint256.fromHex('0x' + sig.substring(64, 64 * 2));
  const v = BigInt('0x' + sig.substring(64 * 2));
  return { r, s, v };
}
=======
  // const str = "Propose(bytes32 space,bytes32 executionHash,string metadataURI,uint256 salt)";
  const str = 'Vote(bytes32 space,uint256 proposal,uint256 choice,uint256 salt)';
  const s = Buffer.from(str);
  const typeHash: string = ethers.utils.keccak256(s);
  console.log('typeHash: ', typeHash);

  return msgHash;
}
>>>>>>> develop
