export const domain = {
  name: 'snapshot-x',
  version: '1',
};

export const proposeTypes = {
  Propose: [
    { name: 'space', type: 'bytes32' },
    { name: 'proposerAddress', type: 'bytes32' },
    { name: 'metadataUri', type: 'string' },
    { name: 'executor', type: 'bytes32' },
    { name: 'executionParamsHash', type: 'bytes32' },
    { name: 'usedVotingStrategiesHash', type: 'bytes32' },
    { name: 'userVotingStrategyParamsFlatHash', type: 'bytes32' },
    { name: 'salt', type: 'uint256' },
  ],
};

export const voteTypes = {
  Vote: [
    { name: 'space', type: 'bytes32' },
    { name: 'voterAddress', type: 'bytes32' },
    { name: 'proposal', type: 'uint256' },
    { name: 'choice', type: 'uint256' },
    { name: 'usedVotingStrategiesHash', type: 'bytes32' },
    { name: 'userVotingStrategyParamsFlatHash', type: 'bytes32' },
    { name: 'salt', type: 'uint256' },
  ],
};

export interface Propose {
  space: string;
  proposerAddress: string;
  metadataUri: string;
  executor: string;
  executionParamsHash: string;
  usedVotingStrategiesHash: string;
  userVotingStrategyParamsFlatHash: string;
  salt: string;
}

export interface Vote {
  space: string;
  voterAddress: string;
  proposal: string;
  choice: string;
  usedVotingStrategiesHash: string;
  userVotingStrategyParamsFlatHash: string;
  salt: string;
}
