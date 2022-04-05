/// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import '@gnosis.pm/zodiac/contracts/guard/Guardable.sol';
import './Interfaces/IStarknetCore.sol';

/**
 * @title Snapshot X L1 Proposal Relayer
 * @author @Orland0x - <orlandothefraser@gmail.com>
 * @dev Work in progress
 */
contract SnapshotXProposalRelayer is Guardable {
  /// The StarkNet Core contract
  IStarknetCore public starknetCore;

  /// Address of the StarkNet contract that will send execution details to this contract in a L2 -> L1 message
  uint256 public l2ExecutionRelayer;

  /**
   * @dev Emitted when a the StarkNet decision executor contract is changed
   * @param _l2ExecutionRelayer The new decision executor contract
   */
  event ChangedL2ExecutionRelayer(uint256 _l2ExecutionRelayer);

  /**
   * @dev Initialization of the functionality. Called internally by the setUp function
   * @param _starknetCore Address of the StarkNet Core contract
   * @param _l2ExecutionRelayer Address of the new decision executor contract
   */
  function setUpSnapshotXProposalRelayer(address _starknetCore, uint256 _l2ExecutionRelayer)
    internal
  {
    starknetCore = IStarknetCore(_starknetCore);
    l2ExecutionRelayer = _l2ExecutionRelayer;
  }

  /**
   * @dev Changes the StarkNet decision executor contract
   * @param _l2ExecutionRelayer Address of the new execution relayer contract
   */
  function changeL2ExecutionRelayer(uint256 _l2ExecutionRelayer) public onlyOwner {
    l2ExecutionRelayer = _l2ExecutionRelayer;
    emit ChangedL2ExecutionRelayer(_l2ExecutionRelayer);
  }

  /**
   * @dev Receives L2 -> L1 message containing proposal execution details
   * @param executionHashLow Lowest 128 bits of the hash of all the transactions in the proposal
   * @param executionHashHigh Highest 128 bits of the hash of all the transactions in the proposal
   * @param hasPassed Whether the proposal passed
   */
  function _receiveFinalizedProposal(
    uint256 callerAddress,
    uint256 hasPassed,
    uint256 executionHashLow,
    uint256 executionHashHigh
  ) internal {
    uint256[] memory payload = new uint256[](4);
    payload[0] = callerAddress;
    payload[1] = hasPassed;
    payload[2] = executionHashLow;
    payload[3] = executionHashHigh;

    /// Returns the message Hash. If proposal execution message did not exist/not received yet, then this will fail
    starknetCore.consumeMessageFromL2(l2ExecutionRelayer, payload);
  }

  /**
   * @dev Checks whether proposal has been received on L1 yet
   * @param executionHash Hash of all the transactions in the proposal
   * @param hasPassed Whether the proposal passed
   * @return isReceived Has the proposal been received
   */
  function isFinalizedProposalreceived(uint256 executionHash, uint256 hasPassed)
    external
    view
    returns (bool isReceived)
  {
    uint256[] memory payload = new uint256[](2);
    payload[0] = executionHash;
    payload[1] = hasPassed;
    bytes32 msgHash = keccak256(
      abi.encodePacked(l2ExecutionRelayer, uint256(uint160(msg.sender)), payload.length, payload)
    );
    return starknetCore.l2ToL1Messages(msgHash) > 0;
  }
}
