export const sharedTypes = {
  Strategy: [
    { name: 'address', type: 'uint256' },
    { name: 'params', type: 'uint256[]' }
  ],
  IndexedStrategy: [
    { name: 'index', type: 'uint256' },
    { name: 'params', type: 'uint256[]' }
  ]
}

export const proposeTypes = {
    Propose: [
      { name: 'authenticator', type: 'uint256' },
      { name: 'space', type: 'uint256' },
      { name: 'author', type: 'address' },
      { name: 'executionStrategy', type: 'Strategy' },
      { name: 'userProposalValidationParams', type: 'uint256[]' },
      { name: 'salt', type: 'uint256' }
    ],
    Strategy: sharedTypes.Strategy
  };

export const voteTypes = {
    Vote: [
      { name: 'authenticator', type: 'uint256' },
      { name: 'space', type: 'uint256' },
      { name: 'voter', type: 'address' },
      { name: 'proposalId', type: 'uint256' },
      { name: 'choice', type: 'uint256' },
      { name: 'userVotingStrategies', type: 'IndexedStrategy[]' },
    ],
    IndexedStrategy: sharedTypes.IndexedStrategy
  };

export const updateProposalTypes = {
  UpdateProposal: [
    { name: 'authenticator', type: 'uint256' },
    { name: 'space', type: 'uint256' },
    { name: 'author', type: 'address' },
    { name: 'proposalId', type: 'uint256' },
    { name: 'executionStrategy', type: 'Strategy' },
    { name: 'salt', type: 'uint256' }
  ],
  Strategy: sharedTypes.Strategy
};


export interface Propose {
    authenticator: string;
    space: string;
    author: string;
    executionStrategy: Strategy;
    userProposalValidationParams: string[];
    salt: string;
}

export interface Vote {
    authenticator: string;
    space: string;
    voter: string;
    proposalId: string;
    choice: string;
    userVotingStrategies: IndexedStrategy[];
}

export interface UpdateProposal {
  authenticator: string;
  space: string;
  author: string;
  proposalId: string;
  executionStrategy: Strategy;
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

export interface IndexedStrategy {
    index: string;
    params: string[];
}

export interface u256 {
  low: string;
  high: string;
}