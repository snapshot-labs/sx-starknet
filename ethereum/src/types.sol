// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Enum} from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

/// @dev Constants used to replace the `bool` type in mappings for gas efficiency.
uint256 constant TRUE = 1;
uint256 constant FALSE = 0;

/// @notice Transaction struct that can be used to represent transactions inside a proposal.
struct MetaTransaction {
    address to;
    uint256 value;
    bytes data;
    Enum.Operation operation;
}

/// @notice The set of possible finalization statuses for a proposal.
///         This is stored inside each Proposal struct.
enum FinalizationStatus {
    Pending,
    Executed,
    Cancelled
}

/// @notice Solidity Representation of a SX-Starknet Proposal
struct Proposal {
    uint32 startTimestamp;
    uint32 minEndTimestamp;
    uint32 maxEndTimestamp;
    FinalizationStatus finalizationStatus;
    uint256 executionPayloadHash;
    uint256 executionStrategy;
    // 0 for Starknet, 1 for Ethereum, 2 for custom
    uint256 authorAddressType;
    uint256 author;
    uint256 activeVotingStrategies;
}

/// @notice Struct to store the votes for a proposal. Used because of Solidity's stack limitations.
struct Votes {
    uint256 votesFor;
    uint256 votesAgainst;
    uint256 votesAbstain;
}

/// @notice The set of possible statuses for a proposal.
enum ProposalStatus {
    VotingDelay,
    VotingPeriod,
    VotingPeriodAccepted,
    Accepted,
    Executed,
    Rejected,
    Cancelled
}
