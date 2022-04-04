/// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import './Interfaces/IStarknetCore.sol';

/**
 * @title StarkNet Commit Contract
 * @author @Orland0x - <orlandothefraser@gmail.com>
 * @notice Allows StarkNet transactions to be committed via a transaction on L1. The contract works in combination with a corresponding authenticator contract on StarkNet.
 * @dev This contract is designed to be a generic standard that that can be used by any StarkNet protocol that wants to allow interactions via an L1 transaction.
 */
contract StarkNetCommit {
  /// The StarkNet core contract.
  IStarknetCore public immutable starknetCore;

  /// Address of the authenticator contract
  uint256 public immutable authL1;

  /**
   * @dev Selector for the L1 handler commit_handler in the authenticator on StarkNet, found via:
   *      from starkware.starknet.compiler.compile import get_selector_from_name
   *      print(get_selector_from_name('commit_handler'))
   */
  uint256 private constant L1_COMMIT_HANDLER =
    730074455009165344009265222749798991923835086840644223690684283307631448552;

  /**
   * @dev Constructor
   * @param _starknetCore Address of the StarkNet core contract
   * @param _authL1 Address of the StarkNet vote authenticator for L1 votes
   */
  constructor(address _starknetCore, uint256 _authL1) {
    starknetCore = IStarknetCore(_starknetCore);
    authL1 = _authL1;
  }

  /**
   * @dev Commit a hash to StarkNet.
   * @param hash The hash to commit
   */
  function commit(bytes32 hash) external {
    uint256[] memory payload = new uint256[](1);
    payload[0] = uint256(hash);
    starknetCore.sendMessageToL2(authL1, L1_COMMIT_HANDLER, payload);
  }

  /**
   * @dev Helper function to compute the hash of a function selector and a payload.
   * @param target The address of the target StarkNet contract
   * @param selector The function selector of the function that should be called in the target contract
   * @param payload The payload of the function that should be called in the target contract
   */
  function getCommit(
    uint256 target,
    uint256 selector,
    bytes memory payload
  ) public pure returns (bytes32) {
    // Using encodePacked here as we do not want to pad the payload.
    return keccak256(abi.encodePacked(target, selector, payload));
  }
}
