/// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@gnosis.pm/zodiac/contracts/interfaces/IAvatar.sol";
import "../interfaces/IStarknetCore.sol";
import {SimpleQuorumExecutionStrategy} from "./SimpleQuorumExecutionStrategy.sol";
import "../types.sol";

/// @title L1 Avatar Execution Strategy
/// @notice Used to execute SX Starknet proposal transactions from an Avatar contract on Ethereum.
/// @dev An Avatar contract is any contract that implements the IAvatar interface, eg a Gnosis Safe.
contract L1AvatarExecutionStrategy is SimpleQuorumExecutionStrategy {
    /// @dev Address of the avatar that this module will pass transactions to.
    address public target;

    /// The Starknet Core contract.
    address public starknetCore;

    /// Address of the StarkNet contract that will send execution details to this contract in a L2 -> L1 message
    uint256 public executionRelayer;

    /// @dev Emitted each time the Target is set.
    event TargetSet(address indexed newTarget);

    /// @dev Emitted each time the Execution Relayer is set.
    event ExecutionRelayerSet(uint256 indexed newExecutionRelayer);

    /// @notice Emitted when a new Avatar Execution Strategy is initialized.
    /// @param _owner Address of the owner of the strategy.
    /// @param _target Address of the avatar that this module will pass transactions to.
    /// @param _starknetCore Address of the StarkNet Core contract.
    /// @param _executionRelayer Address of the StarkNet contract that will send execution details to this contract in a L2 -> L1 message
    /// @param _starknetSpaces Array of whitelisted space contracts.
    /// @param _quorum The quorum required to execute a proposal.
    event AvatarExecutionStrategySetUp(
        address indexed _owner,
        address _target,
        address _starknetCore,
        uint256 _executionRelayer,
        uint256[] _starknetSpaces,
        uint256 _quorum
    );

    /// @notice Constructor
    /// @param _owner Address of the owner of this contract.
    /// @param _target Address of the avatar that this module will pass transactions to.
    /// @param _starknetCore Address of the StarkNet Core contract.
    /// @param _executionRelayer Address of the StarkNet contract that will send execution details to this contract in a L2 -> L1 message
    /// @param _starknetSpaces Array of whitelisted space contracts.
    /// @param _quorum The quorum required to execute a proposal.
    constructor(
        address _owner,
        address _target,
        address _starknetCore,
        uint256 _executionRelayer,
        uint256[] memory _starknetSpaces,
        uint256 _quorum
    ) {
        bytes memory initParams = abi.encode(_owner, _target, _starknetCore, _executionRelayer, _starknetSpaces, _quorum);
        setUp(initParams);
    }

    /// @notice Initialization function, should be called immediately after deploying a new proxy to this contract.
    /// @param initParams ABI encoded parameters, in the same order as the constructor.
    function setUp(bytes memory initParams) public initializer {
        (
            address _owner,
            address _target,
            address _starknetCore,
            uint256 _executionRelayer,
            uint256[] memory _starknetSpaces,
            uint256 _quorum 
        ) = abi.decode(initParams, (address, address, address, uint256, uint256[], uint256));
        __Ownable_init();
        transferOwnership(_owner);
        __SpaceManager_init(_starknetSpaces);
        __SimpleQuorumExecutionStrategy_init(_quorum);
        target = _target;
        starknetCore = _starknetCore;
        executionRelayer = _executionRelayer;
        emit AvatarExecutionStrategySetUp(_owner, _target, _starknetCore, _executionRelayer, _starknetSpaces, _quorum);
    }

    /// @notice Sets the Starknet execution relayer contract
    /// @param _executionRelayer Address of the new execution relayer contract
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
    /// @param executionHash The hash of the proposal transactions.
    /// @param transactions The proposal transactions to be executed.
    function execute(
        uint256 space,
        Proposal memory proposal,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 votesAbstain,
        uint256 executionHash,
        MetaTransaction[] memory transactions
    ) external onlySpace(space) {
        // Call to the Starknet core contract will fail if finalized proposal message was not received on L1.
        _receiveProposal(space, proposal, votesFor, votesAgainst, votesAbstain, executionHash);

        ProposalStatus proposalStatus = getProposalStatus(proposal, votesFor, votesAgainst, votesAbstain);
        if ((proposalStatus != ProposalStatus.Accepted) && (proposalStatus != ProposalStatus.VotingPeriodAccepted)) {
            revert InvalidProposalStatus(proposalStatus);
        }

        if (bytes32(executionHash) != keccak256(abi.encode(transactions))) revert InvalidPayload();

        _execute(transactions);
    }

    /// @dev Reverts if the expected message was not received from L2.
    function _receiveProposal(
        uint256 space,
        Proposal memory proposal,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 votesAbstain,
        uint256 executionHash
    ) internal {
        // The Cairo serialization of the payload sent from L2
        uint256[] memory payload = new uint256[](19);
        payload[0] = space;
        payload[1] = uint256(proposal.startTimestamp);
        payload[2] = uint256(proposal.minEndTimestamp);
        payload[3] = uint256(proposal.maxEndTimestamp);
        payload[4] = uint256(proposal.finalizationStatus);
        payload[5] = proposal.executionPayloadHash;
        payload[6] = proposal.executionStrategy;
        payload[7] = proposal.authorAddressType;
        payload[8] = proposal.author;
        payload[9] = proposal.activeVotingStrategies & (2 ** 128 - 1); 
        payload[10] = proposal.activeVotingStrategies >> 128;

        payload[11] = votesFor & (2 ** 128 - 1);
        payload[12] = votesFor >> 128;

        payload[13] = votesAgainst & (2 ** 128 - 1);
        payload[14] = votesAgainst >> 128;

        payload[15] = votesAbstain & (2 ** 128 - 1);
        payload[16] = votesAbstain >> 128;

        payload[17] = executionHash & (2 ** 128 - 1);
        payload[18] = executionHash >> 128;

        // If proposal execution message did not exist/not received yet, then this will revert.
        IStarknetCore(starknetCore).consumeMessageFromL2(executionRelayer, payload);
    }

    /// @dev Decodes and executes the payload via the avatar.
    function _execute(MetaTransaction[] memory transactions) internal {
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
        return "SimpleQuorumL1Avatar";
    }
}