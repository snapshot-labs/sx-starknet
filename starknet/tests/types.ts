// TODO: need to add verifyingContract
export const domain = {
    name: 'snapshot-x',
    version: '1',
    chainId: '5', // GOERLI
  };

export const proposeTypes = {
    Propose: [
      { name: 'space', type: 'address' },
      { name: 'author', type: 'address' },
      { name: 'executionStrategy', type: 'Strategy' },
      { name: 'userProposalValidationParams', type: 'bytes' },
      { name: 'salt', type: 'uint256' }
    ],
    Strategy: [
      { name: 'addr', type: 'uint256' },
      { name: 'params', type: 'bytes' }
    ]
  };

export interface Propose {
    space: string;
    author: string;
    executionStrategy: Strategy;
    userProposalValidationParams: string;
    salt: string;
}

export interface Strategy {
    addr: string;
    params: string;
}
