// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Enum} from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

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

/// @notice The data stored for each proposal when it is created.
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
