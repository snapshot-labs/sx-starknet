import { number } from 'starknet';
import { BigNumberish } from 'starknet/dist/utils/number';

export const domain = {
  name: 'snapshot-x',
  version: '1'
};

export const proposeTypes = {
  Propose: [
    { name: 'salt', type: 'uint256' },
    { name: 'space', type: 'bytes32' },
    { name: 'executionHash', type: 'bytes32' },
  ]
};

export const voteTypes = {
  Vote: [
    { name: 'salt', type: 'uint256' },
    { name: 'space', type: 'bytes32' },
    { name: 'proposal', type: 'uint32' },
    { name: 'choice', type: 'uint32' }
  ]
};

export interface Propose {
  salt: number;
  space: string;
  executionHash: string;
  // metadataURI: string;
}

export interface Vote {
  salt: number;
  space: string;
  proposal: number;
  choice: number;
}