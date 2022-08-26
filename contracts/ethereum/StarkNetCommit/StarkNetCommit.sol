/// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import '@openzeppelin/contracts/proxy/utils/Initializable.sol';
// import '../Interfaces/IStarknetCore.sol';
// For testing purposes, we use a mock StarkNet messaging contract.
import 'contracts/ethereum/TestContracts/MockStarknetMessaging.sol';

/**
 * @title StarkNet Commit Contract
 * @author @Orland0x - <orlandothefraser@gmail.com>
 * @notice Allows StarkNet transactions to be committed via a transaction on L1. The contract works in combination with a corresponding authenticator contract on StarkNet.
 * @dev This contract is designed to be a generic standard that that can be used by any StarkNet protocol that wants to allow interactions via an L1 transaction.
 */
contract StarkNetCommit is Initializable {
  /// The StarkNet core contract.
  // IStarknetCore public immutable starknetCore;
  /// Using a mock here for testing purposes
  MockStarknetMessaging public immutable starknetCore;

  /**
   * @dev Selector for the L1 handler in the authenticator on StarkNet, found via:
   *      from starkware.starknet.compiler.compile import get_selector_from_name
   *      print(get_selector_from_name('commit'))
   */
  uint256 private constant L1_COMMIT_HANDLER =
    674623595553689999852507866835294387286428733459551884504121875060358224925;

  /**
   * @dev Constructor
   * @param _starknetCore The StarkNet Core contract.
   */
  constructor(MockStarknetMessaging _starknetCore) {
    starknetCore = _starknetCore;
  }

  /**
   * @dev Commit a hash and the sender address to StarkNet.
   * @param _hash The hash to commit
   */
  function commit(uint256 starknetAuthenticator, uint256 _hash) external {
    uint256[] memory payload = new uint256[](2);
    payload[0] = uint256(uint160(msg.sender));
    payload[1] = _hash;
    starknetCore.sendMessageToL2(starknetAuthenticator, L1_COMMIT_HANDLER, payload);
  }
}
