/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../../../../../common";
import type {
  GnosisSafeProxy,
  GnosisSafeProxyInterface,
} from "../../../../../../@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol/GnosisSafeProxy";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "_singleton",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    stateMutability: "payable",
    type: "fallback",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b5060405161017338038061017383398101604081905261002f916100b9565b6001600160a01b0381166100945760405162461bcd60e51b815260206004820152602260248201527f496e76616c69642073696e676c65746f6e20616464726573732070726f766964604482015261195960f21b606482015260840160405180910390fd5b600080546001600160a01b0319166001600160a01b03929092169190911790556100e9565b6000602082840312156100cb57600080fd5b81516001600160a01b03811681146100e257600080fd5b9392505050565b607c806100f76000396000f3fe6080604052600080546001600160a01b0316813563530ca43760e11b1415602857808252602082f35b3682833781823684845af490503d82833e806041573d82fd5b503d81f3fea26469706673582212203e5708692aee5bb2d944ae7b56b765d3aa9c670b8b7fc79853bebbe25587d63a64736f6c63430008090033";

type GnosisSafeProxyConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: GnosisSafeProxyConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class GnosisSafeProxy__factory extends ContractFactory {
  constructor(...args: GnosisSafeProxyConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    _singleton: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<GnosisSafeProxy> {
    return super.deploy(
      _singleton,
      overrides || {}
    ) as Promise<GnosisSafeProxy>;
  }
  override getDeployTransaction(
    _singleton: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(_singleton, overrides || {});
  }
  override attach(address: string): GnosisSafeProxy {
    return super.attach(address) as GnosisSafeProxy;
  }
  override connect(signer: Signer): GnosisSafeProxy__factory {
    return super.connect(signer) as GnosisSafeProxy__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): GnosisSafeProxyInterface {
    return new utils.Interface(_abi) as GnosisSafeProxyInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): GnosisSafeProxy {
    return new Contract(address, _abi, signerOrProvider) as GnosisSafeProxy;
  }
}
