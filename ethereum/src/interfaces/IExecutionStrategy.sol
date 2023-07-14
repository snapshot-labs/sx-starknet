// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Proposal, ProposalStatus} from "../types.sol";

/// @title Execution Strategy Interface
interface IExecutionStrategy {
    /// @notice Thrown when the current status of a proposal does not allow the desired action.
    /// @param status The current status of the proposal.
    error InvalidProposalStatus(ProposalStatus status);

    /// @notice Thrown when the execution of a proposal fails.
    error ExecutionFailed();

    /// @notice Thrown when the execution payload supplied to the execution strategy is not equal
    /// to the payload supplied when the proposal was created.
    error InvalidPayload();

    function getProposalStatus(Proposal memory proposal, uint256 votesFor, uint256 votesAgainst, uint256 votesAbstain)
        external
        view
        returns (ProposalStatus);

    function getStrategyType() external view returns (string memory);
}
