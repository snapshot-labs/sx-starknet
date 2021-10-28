// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './IResults.sol';
import 'hardhat/console.sol';

contract Results {
  address public publisher;

  // Proven storage root for account at block number
  mapping (address => mapping (uint256 => bytes32)) public storageRoot;

  mapping (bytes32 => Result) public proposalResult;

  struct Result {
    bytes32[] scores;
    uint256 quorum;
    bytes32 hash;
  }

  function setPublisher(address _publisher) public {
    require(msg.sender == publisher);
    emit PublisherChanged(publisher, _publisher);
    publisher = _publisher;
  }

  function fixRoot(address account, uint256 blockNumber) public {
    // @TODO Get account storage proof
    bytes32 accountStorageRoot = '0x123...';
    storageRoot[account][blockNumber] = accountStorageRoot;
    emit FixRoot(account, blockNumber, accountStorageRoot);
  }

  function setResults(bytes32 proposal, Result result, bytes memory sig) public {
    // @TODO Check if sig is valid and come from publisher
    proposalResult[proposal] = result;
  }

  function isProposalValid() public view returns (bool) {
    // @TODO Check if proposal pass quorum
    return true;
  }
}
