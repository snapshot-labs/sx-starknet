// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/StarknetCommit.sol";

contract Commit is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        StarknetCommit starknetCommit = StarknetCommit(0x8bF85537c80beCbA711447f66A9a4452e3575E29);

        starknetCommit.commit{value: 500000000000000}(uint256(0x0040394930c6247f8240a0191fb63d1cb54fdc6153c9073fe64ca85a7c9203c8), 12345678);

        vm.stopBroadcast();
    }
}