/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../../../../common";
import type {
  ModuleManager,
  ModuleManagerInterface,
} from "../../../../../@gnosis.pm/safe-contracts/contracts/base/ModuleManager";

const _abi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "module",
        type: "address",
      },
    ],
    name: "DisabledModule",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "module",
        type: "address",
      },
    ],
    name: "EnabledModule",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "module",
        type: "address",
      },
    ],
    name: "ExecutionFromModuleFailure",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "module",
        type: "address",
      },
    ],
    name: "ExecutionFromModuleSuccess",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "prevModule",
        type: "address",
      },
      {
        internalType: "address",
        name: "module",
        type: "address",
      },
    ],
    name: "disableModule",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "module",
        type: "address",
      },
    ],
    name: "enableModule",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "data",
        type: "bytes",
      },
      {
        internalType: "enum Enum.Operation",
        name: "operation",
        type: "uint8",
      },
    ],
    name: "execTransactionFromModule",
    outputs: [
      {
        internalType: "bool",
        name: "success",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "data",
        type: "bytes",
      },
      {
        internalType: "enum Enum.Operation",
        name: "operation",
        type: "uint8",
      },
    ],
    name: "execTransactionFromModuleReturnData",
    outputs: [
      {
        internalType: "bool",
        name: "success",
        type: "bool",
      },
      {
        internalType: "bytes",
        name: "returnData",
        type: "bytes",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "start",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "pageSize",
        type: "uint256",
      },
    ],
    name: "getModulesPaginated",
    outputs: [
      {
        internalType: "address[]",
        name: "array",
        type: "address[]",
      },
      {
        internalType: "address",
        name: "next",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "module",
        type: "address",
      },
    ],
    name: "isModuleEnabled",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b5061092f806100206000396000f3fe608060405234801561001057600080fd5b50600436106100625760003560e01c80632d9ad53d14610067578063468721a71461008f5780635229073f146100a2578063610b5925146100c3578063cc2f8452146100d8578063e009cfde146100f9575b600080fd5b61007a610075366004610636565b61010c565b60405190151581526020015b60405180910390f35b61007a61009d36600461067d565b610147565b6100b56100b036600461067d565b610223565b604051610086929190610758565b6100d66100d1366004610636565b610259565b005b6100eb6100e63660046107b7565b610388565b6040516100869291906107e1565b6100d661010736600461083e565b610480565b600060016001600160a01b0383161480159061014157506001600160a01b038281166000908152602081905260409020541615155b92915050565b6000336001148015906101715750336000908152602081905260409020546001600160a01b031615155b6101aa5760405162461bcd60e51b815260206004820152600560248201526411d4cc4c0d60da1b60448201526064015b60405180910390fd5b6101b7858585855a610599565b905080156101ef5760405133907f6895c13664aa4f67288b25d7a21d7aaa34916e355fb9b6fae0a139a9085becb890600090a261021b565b60405133907facd2c8702804128fdb0db2bb49f6d127dd0181c13fd45dbfe16de0930e2bd37590600090a25b949350505050565b6000606061023386868686610147565b915060405160203d0181016040523d81523d6000602083013e8091505094509492505050565b6102616105e1565b6001600160a01b0381161580159061028357506001600160a01b038116600114155b61029f5760405162461bcd60e51b81526004016101a190610871565b6001600160a01b0381811660009081526020819052604090205416156102ef5760405162461bcd60e51b815260206004820152600560248201526423a998981960d91b60448201526064016101a1565b600060208190527fada5013122d395ba3c54772283fb069b10426056ef8ca54750cb9bb552a59e7d80546001600160a01b0384811680855260408086208054939094166001600160a01b03199384161790935560019094528254169092179055517fecdf3a3effea5783a3c4c2140e677577666428d44ed9d474a0b3a4c9943f84409061037d908390610890565b60405180910390a150565b60606000826001600160401b038111156103a4576103a4610658565b6040519080825280602002602001820160405280156103cd578160200160208202803683370190505b506001600160a01b0380861660009081526020819052604081205492945091165b6001600160a01b0381161580159061041057506001600160a01b038116600114155b801561041b57508482105b156104725780848381518110610433576104336108a4565b6001600160a01b03928316602091820292909201810191909152918116600090815291829052604090912054168161046a816108ba565b9250506103ee565b908352919491935090915050565b6104886105e1565b6001600160a01b038116158015906104aa57506001600160a01b038116600114155b6104c65760405162461bcd60e51b81526004016101a190610871565b6001600160a01b0382811660009081526020819052604090205481169082161461051a5760405162461bcd60e51b8152602060048201526005602482015264475331303360d81b60448201526064016101a1565b6001600160a01b03818116600081815260208190526040808220805487861684528284208054919096166001600160a01b0319918216179095559290915281549092169055517faab4fa2b463f581b2b32cb3b7e3b704b9ce37cc209b5fb4d77e593ace40542769061058d908390610890565b60405180910390a15050565b600060018360018111156105af576105af6108e3565b14156105c8576000808551602087018986f490506105d8565b600080855160208701888a87f190505b95945050505050565b3330146106185760405162461bcd60e51b8152602060048201526005602482015264475330333160d81b60448201526064016101a1565b565b80356001600160a01b038116811461063157600080fd5b919050565b60006020828403121561064857600080fd5b6106518261061a565b9392505050565b634e487b7160e01b600052604160045260246000fd5b80356002811061063157600080fd5b6000806000806080858703121561069357600080fd5b61069c8561061a565b93506020850135925060408501356001600160401b03808211156106bf57600080fd5b818701915087601f8301126106d357600080fd5b8135818111156106e5576106e5610658565b604051601f8201601f19908116603f0116810190838211818310171561070d5761070d610658565b816040528281528a602084870101111561072657600080fd5b82602086016020830137600060208483010152809650505050505061074d6060860161066e565b905092959194509250565b821515815260006020604081840152835180604085015260005b8181101561078e57858101830151858201606001528201610772565b818111156107a0576000606083870101525b50601f01601f191692909201606001949350505050565b600080604083850312156107ca57600080fd5b6107d38361061a565b946020939093013593505050565b604080825283519082018190526000906020906060840190828701845b828110156108235781516001600160a01b0316845292840192908401906001016107fe565b5050506001600160a01b039490941692019190915250919050565b6000806040838503121561085157600080fd5b61085a8361061a565b91506108686020840161061a565b90509250929050565b602080825260059082015264475331303160d81b604082015260600190565b6001600160a01b0391909116815260200190565b634e487b7160e01b600052603260045260246000fd5b60006000198214156108dc57634e487b7160e01b600052601160045260246000fd5b5060010190565b634e487b7160e01b600052602160045260246000fdfea26469706673582212205c658a021f28d6b576a50ee95a19230555b96a46b1bf00ae6cc1bf7982cc514664736f6c63430008090033";

type ModuleManagerConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: ModuleManagerConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class ModuleManager__factory extends ContractFactory {
  constructor(...args: ModuleManagerConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ModuleManager> {
    return super.deploy(overrides || {}) as Promise<ModuleManager>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): ModuleManager {
    return super.attach(address) as ModuleManager;
  }
  override connect(signer: Signer): ModuleManager__factory {
    return super.connect(signer) as ModuleManager__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): ModuleManagerInterface {
    return new utils.Interface(_abi) as ModuleManagerInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): ModuleManager {
    return new Contract(address, _abi, signerOrProvider) as ModuleManager;
  }
}
