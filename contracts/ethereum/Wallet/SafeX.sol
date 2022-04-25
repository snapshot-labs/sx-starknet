/// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import './Interfaces/IStarknetCore.sol';

contract SafeX {
  /// The StarkNet Core contract
  IStarknetCore public starknetCore;

  /// Address of the StarkNet contract that will send execution details to this contract in a L2 -> L1 message
  uint256 public l2ExecutionRelayer;

  /// @dev keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
  bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH =
    0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

  /// @dev keccak256("Transaction(address to,uint256 value,bytes data,uint8 operation,uint256 nonce)");
  bytes32 public constant TRANSACTION_TYPEHASH =
    0x72e9670a7ee00f5fbf1049b8c38e3f22fab7e9b85029e85cf9412f17fdd5c2ad;

  enum Operation {
    Call,
    DelegateCall
  }

  /**
   * @dev Initialization of the functionality. Called internally by the setUp function
   * @param _starknetCore Address of the StarkNet Core contract
   * @param _l2ExecutionRelayer Address of the new execution relayer contract
   */
  constructor(address _starknetCore, uint256 _l2ExecutionRelayer) {
    starknetCore = IStarknetCore(_starknetCore);
    l2ExecutionRelayer = _l2ExecutionRelayer;
  }

  function executeTxs(
    uint256 callerAddress,
    uint256 executionHashLow,
    uint256 executionHashHigh,
    address[] memory tos,
    uint256[] memory values,
    bytes[] memory data,
    Operation[] memory operations
  ) external {
    uint256[] memory payload = new uint256[](3);
    payload[0] = callerAddress;
    payload[1] = executionHashLow;
    payload[2] = executionHashHigh;
    starknetCore.consumeMessageFromL2(callerAddress, payload);

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
    Operation operation
  ) internal {
    bytes32 txHash = getTransactionHash(to, value, data, operation);
    require(execute(to, value, data, operation, gasleft()), 'Module transaction failed');
  }

  function execute(
    address to,
    uint256 value,
    bytes memory data,
    Operation operation,
    uint256 txGas
  ) internal returns (bool success) {
    if (operation == Operation.DelegateCall) {
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
    Operation operation,
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
    Operation operation
  ) public view returns (bytes32 txHash) {
    return keccak256(generateTransactionHashData(to, value, data, operation, 0));
  }
}
