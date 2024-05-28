pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import {L1AvatarExecutionStrategy} from "../src/execution-strategies/L1AvatarExecutionStrategy.sol";
import {L1AvatarExecutionStrategyFactory} from "../src/execution-strategies/L1AvatarExecutionStrategyFactory.sol";
import { stdJson } from "forge-std/StdJson.sol";

contract Deployer is Script {
    string internal deployments;
    string internal deploymentsPath;

    error ImplementationInitializationFailed();

    function run() public {

        vm.startBroadcast();
        L1AvatarExecutionStrategy implementation = new L1AvatarExecutionStrategy();
        address owner = vm.addr(vm.envUint("PRIVATE_KEY"));


        // If the master space is not initialized, initialize it
        address target = address(1);
        address starknetCore = address(2);
        uint256 executionRelayer = 3;
        uint256 quorum = 5;
        if (implementation.owner() == address(0x0)) {
            uint256[] memory starknetSpaces = new uint256[](1);
            starknetSpaces[0] = 4;
            implementation.setUp(
                owner,
                target,
                starknetCore,
                executionRelayer,
                starknetSpaces,
                quorum
            );
        }

        if (implementation.owner() != owner
            || implementation.target() != address(0x1)
            || implementation.starknetCore() != address(2)
            || implementation.executionRelayer() != 3
            || implementation.quorum() != 5) {
            // Initialization failed (e.g. got frontran)
            revert ImplementationInitializationFailed();
        }

        implementation.renounceOwnership();

        L1AvatarExecutionStrategyFactory factory = new L1AvatarExecutionStrategyFactory(address(implementation));
        vm.stopBroadcast();
    }
}
