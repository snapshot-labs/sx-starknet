export const domain = {
    name: "1", // put the name of your dapp to ensure that the signatures will not be used by other DAPP
    version: "1",
    chainId: "0x534e5f474f45524c49" // devnet id 
}

export const domainTypes = {
    StarkNetDomain: [
        { name: "name", type: "felt252" },
        { name: "version", type: "felt252" },
        { name: "chainId", type: "felt252" },
    ],
  };

export const proposeTypes = {
    StarkNetDomain: domainTypes.StarkNetDomain,
    Propose: [
        { name: 'space', type: 'ContractAddress' },
        { name: 'author', type: 'ContractAddress' },
        { name: 'executionStrategy', type: 'Strategy' },
        { name: 'userProposalValidationParams', type: 'felt*' },
        { name: 'salt', type: 'felt252' }
    ],
    Strategy: [
        { name: "address", type: "felt252" },
        { name: "params", type: "felt*" }
    ],
  };

export interface Strategy {
    address: string;
    params: string[];
}

export interface Propose {
    space: string;
    author: string;
    executionStrategy: Strategy;
    userProposalValidationParams: string[];
    salt: string;
}

export interface StarknetSigProposeCalldata extends Propose {
    r: string;
    s: string;
    public_key: string;
}
