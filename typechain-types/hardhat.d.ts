/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { ethers } from "ethers";
import {
  FactoryOptions,
  HardhatEthersHelpers as HardhatEthersHelpersBase,
} from "@nomiclabs/hardhat-ethers/types";

import * as Contracts from ".";

declare module "hardhat/types/runtime" {
  interface HardhatEthersHelpers extends HardhatEthersHelpersBase {
    getContractFactory(
      name: "FallbackManager",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.FallbackManager__factory>;
    getContractFactory(
      name: "Guard",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.Guard__factory>;
    getContractFactory(
      name: "GuardManager",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.GuardManager__factory>;
    getContractFactory(
      name: "ModuleManager",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ModuleManager__factory>;
    getContractFactory(
      name: "OwnerManager",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.OwnerManager__factory>;
    getContractFactory(
      name: "EtherPaymentFallback",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.EtherPaymentFallback__factory>;
    getContractFactory(
      name: "StorageAccessible",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.StorageAccessible__factory>;
    getContractFactory(
      name: "GnosisSafe",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.GnosisSafe__factory>;
    getContractFactory(
      name: "GnosisSafeL2",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.GnosisSafeL2__factory>;
    getContractFactory(
      name: "ISignatureValidator",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ISignatureValidator__factory>;
    getContractFactory(
      name: "GnosisSafeProxy",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.GnosisSafeProxy__factory>;
    getContractFactory(
      name: "IProxy",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IProxy__factory>;
    getContractFactory(
      name: "GnosisSafeProxyFactory",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.GnosisSafeProxyFactory__factory>;
    getContractFactory(
      name: "IProxyCreationCallback",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IProxyCreationCallback__factory>;
    getContractFactory(
      name: "Module",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.Module__factory>;
    getContractFactory(
      name: "FactoryFriendly",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.FactoryFriendly__factory>;
    getContractFactory(
      name: "ModuleProxyFactory",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ModuleProxyFactory__factory>;
    getContractFactory(
      name: "BaseGuard",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.BaseGuard__factory>;
    getContractFactory(
      name: "Guardable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.Guardable__factory>;
    getContractFactory(
      name: "IAvatar",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IAvatar__factory>;
    getContractFactory(
      name: "IGuard",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IGuard__factory>;
    getContractFactory(
      name: "OwnableUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.OwnableUpgradeable__factory>;
    getContractFactory(
      name: "Initializable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.Initializable__factory>;
    getContractFactory(
      name: "ContextUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ContextUpgradeable__factory>;
    getContractFactory(
      name: "Initializable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.Initializable__factory>;
    getContractFactory(
      name: "IERC165",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC165__factory>;
    getContractFactory(
      name: "IStarknetCore",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IStarknetCore__factory>;
    getContractFactory(
      name: "StarkNetCommit",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.StarkNetCommit__factory>;
    getContractFactory(
      name: "IStarknetMessaging",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IStarknetMessaging__factory>;
    getContractFactory(
      name: "MockStarknetMessaging",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.MockStarknetMessaging__factory>;
    getContractFactory(
      name: "StarknetMessaging",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.StarknetMessaging__factory>;
    getContractFactory(
      name: "StarknetSpaceManager",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.StarknetSpaceManager__factory>;
    getContractFactory(
      name: "SXAvatarExecutor",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.SXAvatarExecutor__factory>;

    getContractAt(
      name: "FallbackManager",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.FallbackManager>;
    getContractAt(
      name: "Guard",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.Guard>;
    getContractAt(
      name: "GuardManager",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.GuardManager>;
    getContractAt(
      name: "ModuleManager",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ModuleManager>;
    getContractAt(
      name: "OwnerManager",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.OwnerManager>;
    getContractAt(
      name: "EtherPaymentFallback",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.EtherPaymentFallback>;
    getContractAt(
      name: "StorageAccessible",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.StorageAccessible>;
    getContractAt(
      name: "GnosisSafe",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.GnosisSafe>;
    getContractAt(
      name: "GnosisSafeL2",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.GnosisSafeL2>;
    getContractAt(
      name: "ISignatureValidator",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ISignatureValidator>;
    getContractAt(
      name: "GnosisSafeProxy",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.GnosisSafeProxy>;
    getContractAt(
      name: "IProxy",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IProxy>;
    getContractAt(
      name: "GnosisSafeProxyFactory",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.GnosisSafeProxyFactory>;
    getContractAt(
      name: "IProxyCreationCallback",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IProxyCreationCallback>;
    getContractAt(
      name: "Module",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.Module>;
    getContractAt(
      name: "FactoryFriendly",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.FactoryFriendly>;
    getContractAt(
      name: "ModuleProxyFactory",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ModuleProxyFactory>;
    getContractAt(
      name: "BaseGuard",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.BaseGuard>;
    getContractAt(
      name: "Guardable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.Guardable>;
    getContractAt(
      name: "IAvatar",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IAvatar>;
    getContractAt(
      name: "IGuard",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IGuard>;
    getContractAt(
      name: "OwnableUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.OwnableUpgradeable>;
    getContractAt(
      name: "Initializable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.Initializable>;
    getContractAt(
      name: "ContextUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ContextUpgradeable>;
    getContractAt(
      name: "Initializable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.Initializable>;
    getContractAt(
      name: "IERC165",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC165>;
    getContractAt(
      name: "IStarknetCore",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IStarknetCore>;
    getContractAt(
      name: "StarkNetCommit",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.StarkNetCommit>;
    getContractAt(
      name: "IStarknetMessaging",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IStarknetMessaging>;
    getContractAt(
      name: "MockStarknetMessaging",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.MockStarknetMessaging>;
    getContractAt(
      name: "StarknetMessaging",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.StarknetMessaging>;
    getContractAt(
      name: "StarknetSpaceManager",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.StarknetSpaceManager>;
    getContractAt(
      name: "SXAvatarExecutor",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.SXAvatarExecutor>;

    // default types
    getContractFactory(
      name: string,
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<ethers.ContractFactory>;
    getContractFactory(
      abi: any[],
      bytecode: ethers.utils.BytesLike,
      signer?: ethers.Signer
    ): Promise<ethers.ContractFactory>;
    getContractAt(
      nameOrAbi: string | any[],
      address: string,
      signer?: ethers.Signer
    ): Promise<ethers.Contract>;
  }
}
