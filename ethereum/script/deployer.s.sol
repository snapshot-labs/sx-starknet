// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/StarknetCommit.sol";

address constant STARKNET_CORE_CONTRACT_MAINNET = address(0xc662c410C0ECf747543f5bA90660f6ABeBD9C8c4);
address constant STARKNET_COMMIT_CONTRACT_GOERLI = address(0xde29d060D45901Fb19ED6C6e959EB22d8626708e);
address constant STARKNET_COMMIT_CONTRACT_SEPOLIA = address(0xE2Bb56ee936fd6433DC0F6e7e3b8365C906AA057);

interface ICREATE3Factory {
    function deploy(bytes32 salt, bytes memory bytecode) external returns (address deployedAddress);
}

contract Deployer is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        vm.startBroadcast(deployer);
        bytes32 salt = bytes32(uint256(2));

        // Using the CREATE3 factory maintained by lififinance: https://github.com/lifinance/create3-factory
        ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1).deploy(
            salt,
            abi.encodePacked(type(StarknetCommit).creationCode, abi.encode(STARKNET_CORE_CONTRACT_MAINNET))
        );

        vm.stopBroadcast();
    }
}
