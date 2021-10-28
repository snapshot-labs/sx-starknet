// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';

interface IResults {
  event PublisherChanged(address indexed oldPublisher, address indexed newPublisher);

  event FixRoot(address account, uint256 blockNumber, bytes32 accountStorageRoot);
}
