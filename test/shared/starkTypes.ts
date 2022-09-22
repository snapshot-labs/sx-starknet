export const domain = {
  name: 'snapshot-x',
  version: '1',
  chainId: '0x534e5f474f45524c49', // SN_GOERLI
};

export const domainTypes = {
  StarkNetDomain: [
    {
      name: 'name',
      type: 'string',
    },
    {
      name: 'version',
      type: 'felt',
    },
    {
      name: 'chainId',
      type: 'felt',
    },
  ],
};

export const proposeTypes = {
  StarkNetDomain: domainTypes.StarkNetDomain,
  Propose: [
    { name: 'authenticator', type: 'felt' },
    { name: 'space', type: 'felt' },
    { name: 'proposerAddress', type: 'felt' },
    { name: 'metadataURI', type: 'felt*' },
    { name: 'executor', type: 'felt' },
    { name: 'executionParamsHash', type: 'felt' },
    { name: 'usedVotingStrategiesHash', type: 'felt' },
    { name: 'userVotingStrategyParamsFlatHash', type: 'felt' },
    { name: 'salt', type: 'felt' },
  ],
};

export const voteTypes = {
  StarkNetDomain: domainTypes.StarkNetDomain,
  Vote: [
    { name: 'authenticator', type: 'felt' },
    { name: 'space', type: 'felt' },
    { name: 'voterAddress', type: 'felt' },
    { name: 'proposal', type: 'felt' },
    { name: 'choice', type: 'felt' },
    { name: 'usedVotingStrategiesHash', type: 'felt' },
    { name: 'userVotingStrategyParamsFlatHash', type: 'felt' },
    { name: 'salt', type: 'felt' },
  ],
};

export interface Propose {
  authenticator: string;
  space: string;
  proposerAddress: string;
  metadataURI: string[];
  executor: string;
  executionParamsHash: string;
  usedVotingStrategiesHash: string;
  userVotingStrategyParamsFlatHash: string;
  salt: string;
}

export interface Vote {
  authenticator: string;
  space: string;
  voterAddress: string;
  proposal: string;
  choice: number;
  usedVotingStrategiesHash: string;
  userVotingStrategyParamsFlatHash: string;
  salt: string;
}
