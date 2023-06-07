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

// TODO: Equivalence with sx-evm Proposal struct
/// @notice The data stored for each proposal when it is created.
struct Proposal {
    // The timestamp at which voting power for the proposal is calculated. Overflows at year ~2106.
    uint64 snapshotTimestamp;
    // We store the following 3 timestamps for each proposal despite the fact that they can be
    // inferred from the votingDelay, minVotingDuration, and maxVotingDuration state variables
    // because those variables may be updated during the lifetime of a proposal.
    uint64 startTimestamp;
    uint64 minEndTimestamp;
    uint64 maxEndTimestamp;
    // The hash of the execution payload. We do not store the payload itself to save gas.
    uint256 executionPayloadHash;
    // The address of execution strategy used for the proposal.
    address executionStrategy;
    // The address of the proposal creator.
    address author;
    // An enum that stores whether a proposal is pending, executed, or cancelled.
    FinalizationStatus finalizationStatus;
    // Bit array where the index of each each bit corresponds to whether the voting strategy.
    // at that index is active at the time of proposal creation.
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
