export const domain = {
  name: 'snapshot-x',
  version: '1',
  chainId: '5', // GOERLI
};

export const proposeTypes = {
  Propose: [
    { name: 'authenticator', type: 'bytes32' },
    { name: 'space', type: 'bytes32' },
    { name: 'author', type: 'address' },
    { name: 'metadata_uri', type: 'string' },
    { name: 'executor', type: 'bytes32' },
    { name: 'execution_hash', type: 'bytes32' },
    { name: 'strategies_hash', type: 'bytes32' },
    { name: 'strategies_params_hash', type: 'bytes32' },
    { name: 'salt', type: 'uint256' },
  ],
};

export const voteTypes = {
  Vote: [
    { name: 'authenticator', type: 'bytes32' },
    { name: 'space', type: 'bytes32' },
    { name: 'voter', type: 'address' },
    { name: 'proposal', type: 'uint256' },
    { name: 'choice', type: 'uint256' },
    { name: 'strategies_hash', type: 'bytes32' },
    { name: 'strategies_params_hash', type: 'bytes32' },
    { name: 'salt', type: 'uint256' },
  ],
};

export const sessionKeyTypes = {
  SessionKey: [
    { name: 'address', type: 'address' },
    { name: 'sessionPublicKey', type: 'bytes32' },
    { name: 'sessionDuration', type: 'uint256' },
    { name: 'salt', type: 'uint256' },
  ],
};

export const revokeSessionKeyTypes = {
  RevokeSessionKey: [
    { name: 'sessionPublicKey', type: 'bytes32' },
    { name: 'salt', type: 'uint256' },
  ],
};

export interface Propose {
  authenticator: string;
  space: string;
  author: string;
  metadata_uri: string;
  executor: string;
  execution_hash: string;
  strategies_hash: string;
  strategies_params_hash: string;
  salt: string;
}

export interface Vote {
  authenticator: string;
  space: string;
  voter: string;
  proposal: string;
  choice: number;
  strategies_hash: string;
  strategies_params_hash: string;
  salt: string;
}

export interface SessionKey {
  address: string;
  sessionPublicKey: string;
  sessionDuration: string;
  salt: string;
}

export interface RevokeSessionKey {
  sessionPublicKey: string;
  salt: string;
}
