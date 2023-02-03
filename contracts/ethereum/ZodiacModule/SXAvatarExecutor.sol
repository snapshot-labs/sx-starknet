/// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import '@gnosis.pm/zodiac/contracts/interfaces/IAvatar.sol';
import '../Interfaces/IStarknetCore.sol';
import './StarknetSpaceManager.sol';
import './types.sol';

/**
 * @title Snapshot X L1 execution Zodiac module
 * @author Snapshot Labs
 * @notice Trustless L1 execution of Snapshot X decisions via an Avatar contract such as a Gnosis Safe
 * @dev Work in progress
 */
contract SXAvatarExecutor is StarknetSpaceManager {
  error TransactionsFailed();
  error InvalidExecutionParams();

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
    bytes memory initParams = abi.encode(
      _owner,
      _target,
      _starknetCore,
      _executionRelayer,
      _starknetSpaces
    );
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

  /**
   * @dev Initializes a new proposal execution struct on the receival of a completed proposal from StarkNet
   * @param callerAddress The StarkNet space address which contained the proposal
   * @param proposalOutcome Whether the proposal was accepted / rejected / cancelled
   * @param executionHashLow Lowest 128 bits of the hash of all the transactions in the proposal
   * @param executionHashHigh Highest 128 bits of the hash of all the transactions in the proposal
   * @param executionParams The encoded execution parameters
   */
  function execute(
    uint256 callerAddress,
    uint256 proposalOutcome,
    uint256 executionHashLow,
    uint256 executionHashHigh,
    bytes memory executionParams
  ) external onlySpace(callerAddress) {
    // Call to the StarkNet core contract will fail if finalized proposal message was not received on L1.
    _receiveFinalizedProposal(callerAddress, proposalOutcome, executionHashLow, executionHashHigh);

    // Re-assemble the lowest and highest bytes to get the full execution hash
    // and check that it matches the hash of the execution params.
    bytes32 executionHash = bytes32((executionHashHigh << 128) + executionHashLow);
    if (executionHash != keccak256(executionParams)) revert InvalidExecutionParams();

    if (proposalOutcome == uint256(ProposalOutcome.Accepted)) {
      _execute(executionParams);
    }
  }

  /**
   * @dev Receives L2 -> L1 message containing proposal execution details
   * @param executionHashLow Lowest 128 bits of the hash of all the transactions in the proposal
   * @param executionHashHigh Highest 128 bits of the hash of all the transactions in the proposal
   * @param proposalOutcome Whether the proposal has been accepted / rejected / cancelled
   */
  function _receiveFinalizedProposal(
    uint256 callerAddress,
    uint256 proposalOutcome,
    uint256 executionHashLow,
    uint256 executionHashHigh
  ) internal {
    uint256[] memory payload = new uint256[](4);
    payload[0] = callerAddress;
    payload[1] = proposalOutcome;
    payload[2] = executionHashLow;
    payload[3] = executionHashHigh;

    /// Returns the message Hash. If proposal execution message did not exist/not received yet, then this will fail
    IStarknetCore(starknetCore).consumeMessageFromL2(executionRelayer, payload);
  }

  /// @notice Decodes and executes a batch of transactions from the avatar contract.
  /// @param executionParams The encoded transactions to execute.
  function _execute(bytes memory executionParams) internal {
    MetaTransaction[] memory transactions = abi.decode(executionParams, (MetaTransaction[]));
    for (uint256 i = 0; i < transactions.length; i++) {
      bool success = IAvatar(target).execTransactionFromModule(
        transactions[i].to,
        transactions[i].value,
        transactions[i].data,
        transactions[i].operation
      );
      // If any transaction fails, the entire execution will revert
      if (!success) revert TransactionsFailed();
    }
  }
}
