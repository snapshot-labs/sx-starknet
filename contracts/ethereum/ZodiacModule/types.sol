// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import '@gnosis.pm/safe-contracts/contracts/common/Enum.sol';

struct MetaTransaction {
  address to;
  uint256 value;
  bytes data;
  Enum.Operation operation;
}

enum ProposalOutcome {
  Accepted,
  Rejected,
  Cancelled
}
