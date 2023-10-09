// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {IExecutionStrategy} from "../interfaces/IExecutionStrategy.sol";
import {FinalizationStatus, Proposal, ProposalStatus} from "../types.sol";
import {StarknetSpaceManager} from "./StarknetSpaceManager.sol";

/// @title Simple Quorum Base Execution Strategy
abstract contract SimpleQuorumExecutionStrategy is IExecutionStrategy, StarknetSpaceManager {
    event QuorumUpdated(uint256 newQuorum);

    /// @notice The quorum required to execute a proposal using this strategy.
    uint256 public quorum;

    /// @dev Initializer
    // solhint-disable-next-line func-name-mixedcase
    function __SimpleQuorumExecutionStrategy_init(uint256 _quorum) internal onlyInitializing {
        quorum = _quorum;
    }

    /// @notice Sets the quorum required to execute a proposal using this strategy.
    /// @param _quorum The new quorum.x
    function setQuorum(uint256 _quorum) external onlyOwner {
        quorum = _quorum;
        emit QuorumUpdated(_quorum);
    }

    /// @notice Returns the status of a proposal that uses a simple quorum.
    ///        A proposal is accepted if the for votes exceeds the against votes
    ///        and a quorum of total votes (for + against + abstain) is reached.
    /// @param proposal The proposal struct.
    /// @param votesFor The number of votes for the proposal.
    /// @param votesAgainst The number of votes against the proposal.
    /// @param votesAbstain The number of votes abstaining from the proposal.
    function getProposalStatus(Proposal memory proposal, uint256 votesFor, uint256 votesAgainst, uint256 votesAbstain)
        public
        view
        override
        returns (ProposalStatus)
    {
        bool accepted =
            _quorumReached(quorum, votesFor, votesAgainst, votesAbstain) && _supported(votesFor, votesAgainst);
        if (proposal.finalizationStatus == FinalizationStatus.Cancelled) {
            return ProposalStatus.Cancelled;
        } else if (proposal.finalizationStatus == FinalizationStatus.Executed) {
            return ProposalStatus.Executed;
        } else if (block.timestamp < proposal.startTimestamp) {
            return ProposalStatus.VotingDelay;
        } else if (block.timestamp < proposal.minEndTimestamp) {
            return ProposalStatus.VotingPeriod;
        } else if (block.timestamp < proposal.maxEndTimestamp) {
            if (accepted) {
                return ProposalStatus.VotingPeriodAccepted;
            } else {
                return ProposalStatus.VotingPeriod;
            }
        } else if (accepted) {
            return ProposalStatus.Accepted;
        } else {
            return ProposalStatus.Rejected;
        }
    }

    function _quorumReached(uint256 _quorum, uint256 _votesFor, uint256 _votesAgainst, uint256 _votesAbstain)
        internal
        pure
        returns (bool)
    {
        uint256 totalVotes = _votesFor + _votesAgainst + _votesAbstain;
        return totalVotes >= _quorum;
    }

    function _supported(uint256 _votesFor, uint256 _votesAgainst) internal pure returns (bool) {
        return _votesFor > _votesAgainst;
    }

    function getStrategyType() external view virtual override returns (string memory);

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
