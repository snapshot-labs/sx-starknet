/// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import '@gnosis.pm/zodiac/contracts/core/Module.sol';
import './ProposalRelayer.sol';

/**
 * @title Snapshot X L1 execution Zodiac module
 * @author @Orland0x - <orlandothefraser@gmail.com>
 * @notice Trustless L1 execution of Snapshot X decisions via a Gnosis Safe
 * @dev Work in progress
 */
contract SnapshotXL1Executor is Module, SnapshotXProposalRelayer {
  /// @dev keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
  bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH =
    0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

  /// @dev keccak256("Transaction(address to,uint256 value,bytes data,uint8 operation,uint256 nonce)");
  bytes32 public constant TRANSACTION_TYPEHASH =
    0x72e9670a7ee00f5fbf1049b8c38e3f22fab7e9b85029e85cf9412f17fdd5c2ad;

  /// Counter that is incremented each time a proposal is received.
  uint256 public proposalIndex;

  /// The state of a proposal index exists in one of the 5 categories. This can be queried using the getProposalState view function
  enum ProposalState {
    NotReceived,
    Received,
    Executing,
    Executed,
    Cancelled
  }

  /// Stores the execution details and execution progress of each proposal received
  struct ProposalExecution {
    // array of Transaction Hashes for each transaction in the proposal
    bytes32[] txHashes;
    // counter which stores the index of the next transaction in the proposal that should be executed
    uint256 executionCounter;
    // whether the proposal has been cancelled. Required to fully define the proposal state as a function of this struct
    bool cancelled;
  }

  /// Map of proposal index to the corresponding proposal execution struct
  mapping(uint256 => ProposalExecution) public proposalIndexToProposalExecution;

  /* EVENTS */

  /**
   * @dev Emitted when a new module proxy instance has been deployed
   * @param initiator Address of contract deployer
   * @param _owner Address of the owner of this contract
   * @param _avatar Address that will ultimately execute function calls
   * @param _target Address that this contract will pass transactions to
   * @param _decisionExecutorL2 Address of the StarkNet contract that will send execution details to this contract in a L2 -> L1 message
   * @param _starknetCore Address of the StarkNet Core contract
   */
  event SnapshotXL1ExecutorSetUpComplete(
    address indexed initiator,
    address indexed _owner,
    address indexed _avatar,
    address _target,
    uint256 _decisionExecutorL2,
    address _starknetCore
  );

  /**
   * @dev Emitted when a new proposal is received from StarkNet
   * @param proposalIndex Index of proposal
   */
  event ProposalReceived(uint256 proposalIndex);

  /**
   * @dev Emitted when a Transaction in a proposal is executed.
   * @param proposalIndex Index of proposal
   * @param txHash The transaction hash
   * @notice Could remove to save some gas and only emit event when all txs are executed
   */
  event TransactionExecuted(uint256 proposalIndex, bytes32 txHash);

  /**
   * @dev Emitted when all transactions in a proposal have been executed
   * @param proposalIndex Index of proposal
   */
  event ProposalExecuted(uint256 proposalIndex);

  /**
   * @dev Emitted when a proposal get cancelled
   * @param proposalIndex Index of proposal
   */
  event ProposalCancelled(uint256 proposalIndex);

  /* Constructor */

  /**
   * @dev Constructs the master contract
   * @param _owner Address of the owner of this contract
   * @param _avatar Address that will ultimately execute function calls
   * @param _target Address that this contract will pass transactions to
   * @param _starknetCore Address of the StarkNet Core contract
   * @param _decisionExecutorL2 Address of the StarkNet contract that will send execution details to this contract in a L2 -> L1 message
   */
  constructor(
    address _owner,
    address _avatar,
    address _target,
    address _starknetCore,
    uint256 _decisionExecutorL2
  ) {
    bytes memory initParams = abi.encode(
      _owner,
      _avatar,
      _target,
      _starknetCore,
      _decisionExecutorL2
    );
    setUp(initParams);
  }

  /**
   * @dev Proxy constructor
   * @param initParams Initialization parameters
   */
  function setUp(bytes memory initParams) public override initializer {
    (
      address _owner,
      address _avatar,
      address _target,
      address _starknetCore,
      uint256 _decisionExecutorL2
    ) = abi.decode(initParams, (address, address, address, address, uint256));
    __Ownable_init();
    transferOwnership(_owner);
    avatar = _avatar;
    target = _target;
    setUpSnapshotXProposalRelayer(_starknetCore, _decisionExecutorL2);
    emit SnapshotXL1ExecutorSetUpComplete(
      msg.sender,
      _owner,
      _avatar,
      _target,
      _decisionExecutorL2,
      _starknetCore
    );
  }

  /* External */

  /**
   * @dev Initializes a new proposal execution struct on the receival of a completed proposal from StarkNet
   * @param executionHashLow Lowest 128 bits of the hash of all the transactions in the proposal
   * @param executionHashHigh Highest 128 bits of the hash of all the transactions in the proposal
   * @param hasPassed Whether proposal passed or not
   * @param _txHashes Array of transaction hashes in proposal
   */
  function receiveProposal(
    uint256 executionHashLow,
    uint256 executionHashHigh,
    uint256 hasPassed,
    bytes32[] memory _txHashes
  ) external {
    //External call will fail if finalized proposal message was not received on L1.
    _receiveFinalizedProposal(executionHashLow, executionHashHigh, hasPassed);
    require(hasPassed != 0, 'Proposal did not pass');
    require(_txHashes.length > 0, 'proposal must contain transactions');

    // Re-assemble the lowest and highest bytes to get the full execution hash
    uint256 executionHash = (executionHashHigh << 128) + executionHashLow;
    require(bytes32(executionHash) == keccak256(abi.encode(_txHashes)), 'Invalid execution');

    proposalIndexToProposalExecution[proposalIndex].txHashes = _txHashes;
    proposalIndex++;
    emit ProposalReceived(proposalIndex);
  }

  /**
   * @dev Initializes a new proposal execution struct (To test execution without actually receiving message)
   * @param executionHash Hash of all the transactions in the proposal
   * @param hasPassed Whether proposal passed or not
   * @param _txHashes Array of transaction hashes in proposal
   */
  function receiveProposalTest(
    uint256 executionHash,
    uint256 hasPassed,
    bytes32[] memory _txHashes
  ) external {
    require(hasPassed == 1, 'Proposal did not pass');
    require(_txHashes.length > 0, 'proposal must contain transactions');
    require(bytes32(executionHash) == keccak256(abi.encode(_txHashes)), 'Invalid execution');
    proposalIndexToProposalExecution[proposalIndex].txHashes = _txHashes;
    proposalIndex++;
    emit ProposalReceived(proposalIndex);
  }

  /**
   * @dev Cancels a set of proposals
   * @param _proposalIndexes Array of proposal indexes that should be cancelled
   */
  function cancelProposals(uint256[] memory _proposalIndexes) external onlyOwner {
    for (uint256 i = 0; i < _proposalIndexes.length; i++) {
      require(
        getProposalState(_proposalIndexes[i]) != ProposalState.NotReceived,
        'Proposal not received, nothing to cancel'
      );
      require(
        getProposalState(_proposalIndexes[i]) != ProposalState.Executed,
        'Execution completed, nothing to cancel'
      );
      require(
        proposalIndexToProposalExecution[_proposalIndexes[i]].cancelled == false,
        'proposal is already cancelled'
      );
      //to cancel a proposal, we can set the execution counter for the proposal to the number of transactions in the proposal.
      //We must also set a boolean in the Proposal Execution struct to true, without this there would be no way for the state to differentiate between a cancelled and an executed proposal.
      proposalIndexToProposalExecution[_proposalIndexes[i]]
        .executionCounter = proposalIndexToProposalExecution[_proposalIndexes[i]].txHashes.length;
      proposalIndexToProposalExecution[_proposalIndexes[i]].cancelled = true;
      emit ProposalCancelled(_proposalIndexes[i]);
    }
  }

  /**
   * @dev Executes a single transaction in a proposal
   * @param _proposalIndex Index of proposal
   * @param to the contract to be called by the avatar
   * @param value ether value to pass with the call
   * @param data the data to be executed from the call
   * @param operation Call or DelegateCall indicator
   */
  function executeProposalTx(
    uint256 _proposalIndex,
    address to,
    uint256 value,
    bytes memory data,
    Enum.Operation operation
  ) public {
    bytes32 txHash = getTransactionHash(to, value, data, operation);
    require(
      proposalIndexToProposalExecution[_proposalIndex].txHashes[
        proposalIndexToProposalExecution[_proposalIndex].executionCounter
      ] == txHash,
      'Invalid transaction or invalid transaction order'
    );
    proposalIndexToProposalExecution[_proposalIndex].executionCounter++;
    require(exec(to, value, data, operation), 'Module transaction failed');
    emit TransactionExecuted(_proposalIndex, txHash);
    if (getProposalState(_proposalIndex) == ProposalState.Executed) {
      emit ProposalExecuted(_proposalIndex);
    }
  }

  /**
   * @dev Wrapper function around executeProposalTx that will execute all transactions in a proposal
   * @param _proposalIndex Index of proposal
   * @param tos Array of contracts to be called by the avatar
   * @param values Array of ether values to pass with the calls
   * @param data Array of data to be executed from the calls
   * @param operations Array of Call or DelegateCall indicators
   */
  function executeProposalTxBatch(
    uint256 _proposalIndex,
    address[] memory tos,
    uint256[] memory values,
    bytes[] memory data,
    Enum.Operation[] memory operations
  ) external {
    for (uint256 i = 0; i < tos.length; i++) {
      executeProposalTx(_proposalIndex, tos[i], values[i], data[i], operations[i]);
    }
  }

  /* VIEW FUNCTIONS */

  /**
   * @dev Returns state of proposal
   * @param _proposalIndex Index of proposal
   */
  function getProposalState(uint256 _proposalIndex) public view returns (ProposalState) {
    ProposalExecution storage proposalExecution = proposalIndexToProposalExecution[_proposalIndex];
    if (proposalExecution.txHashes.length == 0) {
      return ProposalState.NotReceived;
    } else if (proposalExecution.cancelled) {
      return ProposalState.Cancelled;
    } else if (proposalExecution.executionCounter == 0) {
      return ProposalState.Received;
    } else if (proposalExecution.txHashes.length == proposalExecution.executionCounter) {
      return ProposalState.Executed;
    } else {
      return ProposalState.Executing;
    }
  }

  /**
   * @dev Gets number of transactions in a proposal
   * @param _proposalIndex Index of proposal
   * @return numTx Number of transactions in the proposal
   */
  function getNumOfTxInProposal(uint256 _proposalIndex) public view returns (uint256 numTx) {
    require(_proposalIndex < proposalIndex, 'Invalid Proposal Index');
    return proposalIndexToProposalExecution[_proposalIndex].txHashes.length;
  }

  /**
   * @dev Gets hash of transaction in a proposal
   * @param _proposalIndex Index of proposal
   * @param txIndex Index of transaction in proposal
   * @param txHash Transaction Hash
   */
  function getTxHash(uint256 _proposalIndex, uint256 txIndex) public view returns (bytes32 txHash) {
    require(_proposalIndex < proposalIndex, 'Invalid Proposal Index');
    require(txIndex < proposalIndexToProposalExecution[_proposalIndex].txHashes.length);
    return proposalIndexToProposalExecution[_proposalIndex].txHashes[txIndex];
  }

  /**
   * @dev Gets whether transaction has been executed
   * @param _proposalIndex Index of proposal
   * @param txIndex Index of transaction in proposal
   * @param isExecuted Is transaction executed
   */
  function isTxExecuted(uint256 _proposalIndex, uint256 txIndex)
    public
    view
    returns (bool isExecuted)
  {
    require(_proposalIndex < proposalIndex, 'Invalid Proposal Index');
    require(txIndex < proposalIndexToProposalExecution[_proposalIndex].txHashes.length);
    return proposalIndexToProposalExecution[_proposalIndex].executionCounter > txIndex;
  }

  /**
   * @dev Generates the data for the module transaction hash (required for signing)
   * @param to the contract to be called by the avatar
   * @param value ether value to pass with the call
   * @param data the data to be executed from the call
   * @param operation Call or DelegateCall indicator
   * @return txHashData Transaction hash data
   */
  function generateTransactionHashData(
    address to,
    uint256 value,
    bytes memory data,
    Enum.Operation operation,
    uint256 nonce
  ) public view returns (bytes memory txHashData) {
    uint256 chainId = block.chainid;
    bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, chainId, this));
    bytes32 transactionHash = keccak256(
      abi.encode(TRANSACTION_TYPEHASH, to, value, keccak256(data), operation, nonce)
    );
    return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator, transactionHash);
  }

  /**
   * @dev Generates transaction hash
   * @param to the contract to be called by the avatar
   * @param value ether value to pass with the call
   * @param data the data to be executed from the call
   * @param operation Call or DelegateCall indicator
   * @return txHash Transaction hash
   */
  function getTransactionHash(
    address to,
    uint256 value,
    bytes memory data,
    Enum.Operation operation
  ) public view returns (bytes32 txHash) {
    return keccak256(generateTransactionHashData(to, value, data, operation, 0));
  }
}
