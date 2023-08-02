export const domainTypes = {
  StarkNetDomain: [
    { name: 'name', type: 'felt252' },
    { name: 'version', type: 'felt252' },
    { name: 'chainId', type: 'felt252' },
    { name: 'verifyingContract', type: 'ContractAddress' },
  ],
};

export const proposeTypes = {
  StarkNetDomain: domainTypes.StarkNetDomain,
  Propose: [
    { name: 'space', type: 'ContractAddress' },
    { name: 'author', type: 'ContractAddress' },
    { name: 'executionStrategy', type: 'Strategy' },
    { name: 'userProposalValidationParams', type: 'felt*' },
    { name: 'salt', type: 'felt252' },
  ],
  Strategy: [
    { name: 'address', type: 'felt252' },
    { name: 'params', type: 'felt*' },
  ],
};

export const voteTypes = {
  StarkNetDomain: domainTypes.StarkNetDomain,
  Vote: [
    { name: 'space', type: 'ContractAddress' },
    { name: 'voter', type: 'ContractAddress' },
    { name: 'proposalId', type: 'u256' },
    { name: 'choice', type: 'felt252' },
    { name: 'userVotingStrategies', type: 'IndexedStrategy*' },
  ],
  IndexedStrategy: [
    { name: 'index', type: 'felt252' },
    { name: 'params', type: 'felt*' },
  ],
  u256: [
    { name: 'low', type: 'felt252' },
    { name: 'high', type: 'felt252' },
  ],
};

export const updateProposalTypes = {
  StarkNetDomain: domainTypes.StarkNetDomain,
  UpdateProposal: [
    { name: 'space', type: 'ContractAddress' },
    { name: 'author', type: 'ContractAddress' },
    { name: 'proposalId', type: 'u256' },
    { name: 'executionStrategy', type: 'Strategy' },
    { name: 'salt', type: 'felt252' },
  ],
  Strategy: [
    { name: 'address', type: 'felt252' },
    { name: 'params', type: 'felt*' },
  ],
  u256: [
    { name: 'low', type: 'felt252' },
    { name: 'high', type: 'felt252' },
  ],
};

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

export interface Propose {
  space: string;
  author: string;
  executionStrategy: Strategy;
  userProposalValidationParams: string[];
  salt: string;
}

export interface Vote {
  space: string;
  voter: string;
  proposalId: u256;
  choice: string;
  userVotingStrategies: IndexedStrategy[];
}

export interface UpdateProposal {
  space: string;
  author: string;
  proposalId: u256;
  executionStrategy: Strategy;
  salt: string;
}

export interface StarknetSigProposeCalldata extends Propose {
  r: string;
  s: string;
  public_key: string;
}

export interface StarknetSigVoteCalldata extends Vote {
  r: string;
  s: string;
  public_key: string;
}

export interface StarknetSigUpdateProposalCalldata extends UpdateProposal {
  r: string;
  s: string;
  public_key: string;
}
