export const sharedTypes = {
  Strategy: [
    { name: 'address', type: 'uint256' },
    { name: 'params', type: 'uint256[]' },
  ],
  IndexedStrategy: [
    { name: 'index', type: 'uint256' },
    { name: 'params', type: 'uint256[]' },
  ],
};

export const proposeTypes = {
  Propose: [
    { name: 'authenticator', type: 'uint256' },
    { name: 'space', type: 'uint256' },
    { name: 'author', type: 'address' },
    { name: 'metadataUri', type: 'uint256[]' },
    { name: 'executionStrategy', type: 'Strategy' },
    { name: 'userProposalValidationParams', type: 'uint256[]' },
    { name: 'salt', type: 'uint256' },
  ],
  Strategy: sharedTypes.Strategy,
};

export const voteTypes = {
  Vote: [
    { name: 'authenticator', type: 'uint256' },
    { name: 'space', type: 'uint256' },
    { name: 'voter', type: 'address' },
    { name: 'proposalId', type: 'uint256' },
    { name: 'choice', type: 'uint256' },
    { name: 'userVotingStrategies', type: 'IndexedStrategy[]' },
    { name: 'metadataUri', type: 'uint256[]' },
  ],
  IndexedStrategy: sharedTypes.IndexedStrategy,
};

export const updateProposalTypes = {
  UpdateProposal: [
    { name: 'authenticator', type: 'uint256' },
    { name: 'space', type: 'uint256' },
    { name: 'author', type: 'address' },
    { name: 'proposalId', type: 'uint256' },
    { name: 'executionStrategy', type: 'Strategy' },
    { name: 'metadataUri', type: 'uint256[]' },
    { name: 'salt', type: 'uint256' },
  ],
  Strategy: sharedTypes.Strategy,
};

export interface Propose {
  authenticator: string;
  space: string;
  author: string;
  metadataUri: string[];
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
  metadataUri: string[];
}

export interface UpdateProposal {
  authenticator: string;
  space: string;
  author: string;
  proposalId: string;
  executionStrategy: Strategy;
  metadataUri: string[];
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
