import { number } from 'starknet';
import { BigNumberish } from 'starknet/dist/utils/number';

export const domain = {
  name: 'snapshot-x',
  version: '1',
};

export const proposeTypes = {
  Propose: [
    { name: 'space', type: 'bytes32' },
    { name: 'executionHash', type: 'bytes32' },
    { name: 'metadataURI', type: 'string' },
    { name: 'salt', type: 'uint256' },
  ],
};

export const voteTypes = {
  Vote: [
    { name: 'space', type: 'bytes32' },
    { name: 'proposal', type: 'uint256' },
    { name: 'choice', type: 'uint256' },
    { name: 'salt', type: 'uint256' },
  ],
};

export interface Propose {
  space: string;
  executionHash: string;
  metadataURI: string;
  salt: number;
}

export interface Vote {
  space: string;
  proposal: number;
  choice: number;
  salt: number;
}
