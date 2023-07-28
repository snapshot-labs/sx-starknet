// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/StarkNetCommit.sol";

interface SingletonFactory {
    function deploy(bytes memory _initCode, bytes32 salt) external returns (address payable);
}

contract Deployer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        SingletonFactory singletonFactory = SingletonFactory(0xce0042B868300000d44A59004Da54A005ffdcf9f);
        bytes32 salt = bytes32(uint256(2));

        singletonFactory.deploy(
            abi.encodePacked(
                type(StarkNetCommit).creationCode, abi.encode(address(0xde29d060D45901Fb19ED6C6e959EB22d8626708e))
            ),
            salt
        );

        vm.stopBroadcast();
    }
}
