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
    { name: 'space', type: 'felt' },
    { name: 'author', type: 'felt' },
    { name: 'metadata_uri', type: 'felt*' },
    { name: 'executor', type: 'felt' },
    { name: 'execution_hash', type: 'felt' },
    { name: 'strategies_hash', type: 'felt' },
    { name: 'strategies_params_hash', type: 'felt' },
    { name: 'salt', type: 'felt' },
  ],
};

export const voteTypes = {
  StarkNetDomain: domainTypes.StarkNetDomain,
  Vote: [
    { name: 'space', type: 'felt' },
    { name: 'voter', type: 'felt' },
    { name: 'proposal', type: 'felt' },
    { name: 'choice', type: 'felt' },
    { name: 'strategies_hash', type: 'felt' },
    { name: 'strategies_params_hash', type: 'felt' },
    { name: 'salt', type: 'felt' },
  ],
};

export const revokeSessionKeyTypes = {
  StarkNetDomain: domainTypes.StarkNetDomain,
  RevokeSessionKey: [{ name: 'salt', type: 'felt' }],
};

export interface Propose {
  space: string;
  author: string;
  metadata_uri: string[];
  executor: string;
  execution_hash: string;
  strategies_hash: string;
  strategies_params_hash: string;
  salt: string;
}

export interface Vote {
  space: string;
  voter: string;
  proposal: string;
  choice: number;
  strategies_hash: string;
  strategies_params_hash: string;
  salt: string;
}

export interface RevokeSessionKey {
  salt: string;
}
