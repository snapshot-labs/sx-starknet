// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from 'forge-std/Script.sol';
import {OZVotesToken} from '../src/token/OZVotesToken.sol';

contract DeployDemoToken is Script {
  function run() public {
    uint256 deployerPk = vm.envUint('ETH_PRIVATE_KEY');
    address deployer = vm.addr(deployerPk);

    vm.startBroadcast(deployerPk);

    OZVotesToken token = new OZVotesToken('Demo Token', 'DEMO', 1_000_000 ether);
    console.log('Token deployed at:', address(token));

    token.delegate(deployer);
    console.log('Self-delegated. numCheckpoints:', token.numCheckpoints(deployer));

    vm.stopBroadcast();
  }
}
