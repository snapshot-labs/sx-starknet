/// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "zodiac/interfaces/IAvatar.sol";
import "../interfaces/IStarknetCore.sol";
import {SimpleQuorumExecutionStrategy} from "./SimpleQuorumExecutionStrategy.sol";
import "../types.sol";
/**
 * @title Snapshot X L1 execution Zodiac module
 * @author Snapshot Labs
 * @notice Trustless L1 execution of Snapshot X decisions via an Avatar contract such as a Gnosis Safe
 * @dev Work in progress
 */

contract L1AvatarExecutionStrategy is SimpleQuorumExecutionStrategy {
    /// @dev Address of the avatar that this module will pass transactions to.
    address public target;

    /// The StarkNet Core contract
    address public starknetCore;

    /// Address of the StarkNet contract that will send execution details to this contract in a L2 -> L1 message
    uint256 public executionRelayer;

    /// @dev Emitted each time the Target is set.
    event TargetSet(address indexed newTarget);

    /// @dev Emitted each time the Execution Relayer is set.
    event ExecutionRelayerSet(uint256 indexed newExecutionRelayer);

    /**
     * @dev Emitted when a new module proxy instance has been deployed
     * @param _owner Address of the owner of this contract
     * @param _target Address that this contract will pass transactions to
     * @param _starknetCore Address of the StarkNet Core contract
     * @param _executionRelayer Address of the StarkNet contract that will send execution details to this contract in a L2 -> L1 message
     */
    event SXAvatarExecutorSetUp(
        address indexed _owner,
        address _target,
        address _starknetCore,
        uint256 _executionRelayer,
        uint256[] _starknetSpaces
    );

    /**
     * @dev Constructs the master contract
     * @param _owner Address of the owner of this contract
     * @param _target Address that this contract will pass transactions to
     * @param _starknetCore Address of the StarkNet Core contract
     * @param _executionRelayer Address of the StarkNet contract that will send execution details to this contract in a L2 -> L1 message
     * @param _starknetSpaces of spaces deployed on StarkNet that are allowed to execute proposals via this contract
     */
    constructor(
        address _owner,
        address _target,
        address _starknetCore,
        uint256 _executionRelayer,
        uint256[] memory _starknetSpaces
    ) {
        bytes memory initParams = abi.encode(_owner, _target, _starknetCore, _executionRelayer, _starknetSpaces);
        setUp(initParams);
    }

    /**
     * @dev Proxy constructor
     * @param initParams Initialization parameters
     */
    function setUp(bytes memory initParams) public initializer {
        (
            address _owner,
            address _target,
            address _starknetCore,
            uint256 _executionRelayer,
            uint256[] memory _starknetSpaces
        ) = abi.decode(initParams, (address, address, address, uint256, uint256[]));
        __Ownable_init();
        transferOwnership(_owner);
        __SpaceManager_init(_starknetSpaces);
        target = _target;
        starknetCore = _starknetCore;
        executionRelayer = _executionRelayer;

        emit SXAvatarExecutorSetUp(_owner, _target, _starknetCore, _executionRelayer, _starknetSpaces);
    }

    /**
     * @dev Changes the StarkNet execution relayer contract
     * @param _executionRelayer Address of the new execution relayer contract
     */
    function setExecutionRelayer(uint256 _executionRelayer) external onlyOwner {
        executionRelayer = _executionRelayer;
        emit ExecutionRelayerSet(_executionRelayer);
    }

    /// @notice Sets the target address
    /// @param _target Address of the avatar that this module will pass transactions to.
    function setTarget(address _target) external onlyOwner {
        target = _target;
        emit TargetSet(_target);
    }

    /// @notice Executes a proposal
    /// @param space The address of the space that the proposal was created in.
    /// @param proposal The proposal struct.
    /// @param votesFor The number of votes for the proposal.
    /// @param votesAgainst The number of votes against the proposal.
    /// @param votesAbstain The number of votes abstaining from the proposal.
    /// @param executionHash The hash of the execution payload.
    /// @param payload The encoded execution payload.
    function execute(
        uint256 space,
        Proposal memory proposal,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 votesAbstain,
        bytes32 executionHash,
        bytes memory payload
    ) external onlySpace(space) {
        // Call to the Starknet core contract will fail if finalized proposal message was not received on L1.
        _receiveProposal(space, proposal, votesFor, votesAgainst, votesAbstain, executionHash);

        ProposalStatus proposalStatus = getProposalStatus(proposal, votesFor, votesAgainst, votesAbstain);
        if ((proposalStatus != ProposalStatus.Accepted) && (proposalStatus != ProposalStatus.VotingPeriodAccepted)) {
            revert InvalidProposalStatus(proposalStatus);
        }

        if (executionHash != keccak256(payload)) revert InvalidPayload();

        _execute(payload);
    }

    /// @dev Reverts if the expected message was not received from L2.
    function _receiveProposal(
        uint256 space,
        Proposal memory proposal,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 votesAbstain,
        bytes32 executionHash
    ) internal {
        uint256[] memory payload = new uint256[](15);
        payload[0] = space;
        // The serialized Proposal struct
        // TODO: this is probably an incorrect serialization
        payload[1] = uint256(proposal.snapshotTimestamp);
        payload[2] = uint256(proposal.startTimestamp);
        payload[3] = uint256(proposal.minEndTimestamp);
        payload[4] = uint256(proposal.maxEndTimestamp);
        payload[5] = proposal.executionPayloadHash;
        payload[6] = uint256(uint160(proposal.executionStrategy));
        payload[7] = uint256(uint160(proposal.author));
        payload[8] = uint256(proposal.finalizationStatus);
        payload[9] = proposal.activeVotingStrategies;

        payload[10] = votesFor;
        payload[11] = votesAgainst;
        payload[12] = votesAbstain;

        payload[13] = uint256(executionHash >> 128); // High 128 bits of executionHash
        payload[14] = uint256(executionHash) & (2 ** 128 - 1); // Low 128 bits of executionHash

        // If proposal execution message did not exist/not received yet, then this will revert.
        IStarknetCore(starknetCore).consumeMessageFromL2(executionRelayer, payload);
    }

    /// @dev Decodes and executes the payload via the avatar.
    function _execute(bytes memory payload) internal {
        MetaTransaction[] memory transactions = abi.decode(payload, (MetaTransaction[]));
        for (uint256 i = 0; i < transactions.length; i++) {
            bool success = IAvatar(target).execTransactionFromModule(
                transactions[i].to, transactions[i].value, transactions[i].data, transactions[i].operation
            );
            // If any transaction fails, the entire execution will revert.
            if (!success) revert ExecutionFailed();
        }
    }

    /// @notice Returns the type of execution strategy.
    function getStrategyType() external pure override returns (string memory) {
        return "SimpleQuorumL1AvatarExecutionStrategy";
    }
}
