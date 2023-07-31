// import { TypedData }  from "starknet";
// export const typedDataPropose: TypedData = {
//     types: {
//         StarkNetDomain: [
//             { name: "name", type: "felt252" },
//             { name: "version", type: "felt252" },
//             { name: "chainId", type: "felt252" },
//         ],
//         Strategy: [
//             { name: "address", type: "felt252" },
//             { name: "params", type: "felt*" }
//         ],
//         Propose: [
//             { name: 'space', type: 'ContractAddress' },
//             { name: 'author', type: 'ContractAddress' },
//             { name: 'executionStrategy', type: 'Strategy' },
//             { name: 'userProposalValidationParams', type: 'felt*' },
//             { name: 'salt', type: 'felt252' }
//         ]
//     },
//     primaryType: "Propose",
//     domain: {
//         name: "1", // put the name of your dapp to ensure that the signatures will not be used by other DAPP
//         version: "1",
//         chainId: "0x534e5f474f45524c49" // devnet id 
//     },
//     message: {
//         space: "0x0000000000000000000000000000000000007777",
//         author: "0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a",
//         executionStrategy: {
//             address: "0x0000000000000000000000000000000000001234",
//             params: [5,6,7,8]
//         },
//         userProposalValidationParams: ["0x1", "0x2", "0x3", "0x4"],
//         salt: "0x0"
//     },
// };

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
