export const proposeTypes = {
    Propose: [
      { name: 'authenticator', type: 'uint256' },
      { name: 'space', type: 'uint256' },
      { name: 'author', type: 'address' },
      { name: 'executionStrategy', type: 'Strategy' },
      { name: 'userProposalValidationParams', type: 'uint256[]' },
      { name: 'salt', type: 'uint256' }
    ],
    Strategy: [
      { name: 'address', type: 'uint256' },
      { name: 'params', type: 'uint256[]' }
    ]
  };

export interface Propose {
    authenticator: string;
    space: string;
    author: string;
    executionStrategy: Strategy;
    userProposalValidationParams: string[];
    salt: string;
}

export interface EthereumSigProposeCalldata {
  r: u256;
  s: u256;
  v: number;
  space: string;
  author: string;
  executionStrategy: Strategy;
  userProposalValidationParams: string[];
  salt: string;
}


export interface Strategy {
    address: string;
    params: string[];
}

export interface u256 {
  low: string;
  high: string;
}