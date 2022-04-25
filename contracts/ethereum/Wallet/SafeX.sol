/// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@gnosis.pm/zodiac/contracts/core/Module.sol";
import "./ProposalRelayer.sol";
import "./Interfaces/IStarknetCore.sol";

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

  /**
   * @dev Constructs the master contract
   * @param _starknetCore Address of the StarkNet Core contract
   * @param _l2ExecutionRelayer Address of the StarkNet contract that will send execution details to this contract in a L2 -> L1 message
   */
  constructor(address _starknetCore, uint256 _l2ExecutionRelayer) {
    bytes memory initParams = abi.encode(_starknetCore, _l2ExecutionRelayer);
    setUp(initParams);
  }

  /**
   * @dev Proxy constructor
   * @param initParams Initialization parameters
   */
  function setUp(bytes memory initParams) public override initializer {
    (address _starknetCore, uint256 _l2ExecutionRelayer) = abi.decode(
      initParams,
      (address, uint256)
    );
    setUpSnapshotXProposalRelayer(_starknetCore, _l2ExecutionRelayer);
  }

  /* External */

  /**
   * @dev Initializes a new proposal execution struct on the receival of a completed proposal from StarkNet
   * @param executionHashLow Lowest 128 bits of the hash of all the transactions in the proposal
   * @param executionHashHigh Highest 128 bits of the hash of all the transactions in the proposal
   * @param proposalOutcome Whether the proposal was accepted / rejected / cancelled
   */
  function receiveProposal(
    uint256 callerAddress,
    uint256 proposalOutcome,
    uint256 executionHashLow,
    uint256 executionHashHigh,
    address[] memory tos,
    uint256[] memory values,
    bytes[] memory data,
    Enum.Operation[] memory operations
  ) external {
    //External call will fail if finalized proposal message was not received on L1.
    _receiveFinalizedProposal(
      callerAddress,
      proposalOutcome,
      executionHashLow,
      executionHashHigh
    );
    for (uint256 i = 0; i < tos.length; i++) {
      _executeTx(tos[i], values[i], data[i], operations[i]);
    }
  }

  /**
   * @dev Executes a single transaction in a proposal
   * @param to the contract to be called by the avatar
   * @param value ether value to pass with the call
   * @param data the data to be executed from the call
   * @param operation Call or DelegateCall indicator
   */
  function _executeTx(
    address to,
    uint256 value,
    bytes memory data,
    Enum.Operation operation
  ) internal {
    bytes32 txHash = getTransactionHash(to, value, data, operation);
    require(
      execute(to, value, data, operation, gasleft()),
      "Module transaction failed"
    );
  }

  function execute(
    address to,
    uint256 value,
    bytes memory data,
    Enum.Operation operation,
    uint256 txGas
  ) internal returns (bool success) {
    if (operation == Enum.Operation.DelegateCall) {
      // solhint-disable-next-line no-inline-assembly
      assembly {
        success := delegatecall(txGas, to, add(data, 0x20), mload(data), 0, 0)
      }
    } else {
      // solhint-disable-next-line no-inline-assembly
      assembly {
        success := call(txGas, to, value, add(data, 0x20), mload(data), 0, 0)
      }
    }
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
    bytes32 domainSeparator = keccak256(
      abi.encode(DOMAIN_SEPARATOR_TYPEHASH, chainId, this)
    );
    bytes32 transactionHash = keccak256(
      abi.encode(
        TRANSACTION_TYPEHASH,
        to,
        value,
        keccak256(data),
        operation,
        nonce
      )
    );
    return
      abi.encodePacked(
        bytes1(0x19),
        bytes1(0x01),
        domainSeparator,
        transactionHash
      );
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
    return
      keccak256(generateTransactionHashData(to, value, data, operation, 0));
  }

  receive() external payable {}
}
