import { ethers } from 'hardhat';
import { TypedDataDomain, TypedDataField } from '@ethersproject/abstract-signer';
import { _TypedDataEncoder } from '@ethersproject/hash';

function getHash(
  domain: TypedDataDomain,
  types: Record<string, TypedDataField[]>,
  message: Record<string, any>
) {
  const msgHash = _TypedDataEncoder.hash(domain, types, message);

  // Stub code to generate and print the type hash
  // const str = "Propose(bytes32 space,bytes32 executionHash,string metadataURI,uint256 salt)";
  const str = 'Vote(bytes32 space,uint256 proposal,uint256 choice,uint256 salt)';
  const s = Buffer.from(str);
  const typeHash: string = ethers.utils.keccak256(s);
  console.log('typeHash: ', typeHash);

  return msgHash;
}
