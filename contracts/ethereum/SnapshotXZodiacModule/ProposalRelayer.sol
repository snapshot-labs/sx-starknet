/// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

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
  uint256 public decisionExecutorL2;

  /**
   * @dev Emitted when a the StarkNet decision executor contract is changed
   * @param _decisionExecutorL2 The new decision executor contract
   */
  event ChangedDecisionExecutorL2(uint256 _decisionExecutorL2);

  /**
   * @dev Initialization of the functionality. Called internally by the setUp function
   * @param _starknetCore Address of the StarkNet Core contract
   * @param _decisionExecutorL2 Address of the new decision executor contract
   */
  function setUpSnapshotXProposalRelayer(address _starknetCore, uint256 _decisionExecutorL2)
    internal
  {
    starknetCore = IStarknetCore(_starknetCore);
    decisionExecutorL2 = _decisionExecutorL2;
  }

  /**
   * @dev Changes the StarkNet decision executor contract
   * @param _decisionExecutorL2 Address of the new decision executor contract
   */
  function changeDecisionExecutorL2(uint256 _decisionExecutorL2) public onlyOwner {
    decisionExecutorL2 = _decisionExecutorL2;
    emit ChangedDecisionExecutorL2(_decisionExecutorL2);
  }

  /**
   * @dev Receives L2 -> L1 message containing proposal execution details
   * @param executionDetails Hash of all the transactions in the proposal
   * @param hasPassed Whether the proposal passed
   */
  function _receiveFinalizedProposal(uint256 executionDetails, uint256 hasPassed) internal {
    uint256[] memory payload = new uint256[](2);
    payload[0] = executionDetails;
    payload[1] = hasPassed;
    /// Returns the message Hash. If proposal execution message did not exist/not received yet, then this will fail
    starknetCore.consumeMessageFromL2(decisionExecutorL2, payload);
  }

  /**
   * @dev Checks whether proposal has been received on L1 yet
   * @param executionDetails Hash of all the transactions in the proposal
   * @param hasPassed Whether the proposal passed
   * @return isReceived Has the proposal been received
   */
  function isFinalizedProposalreceived(uint256 executionDetails, uint256 hasPassed)
    external
    view
    returns (bool isReceived)
  {
    uint256[] memory payload = new uint256[](2);
    payload[0] = executionDetails;
    payload[1] = hasPassed;
    bytes32 msgHash = keccak256(
      abi.encodePacked(decisionExecutorL2, uint256(uint160(msg.sender)), payload.length, payload)
    );
    return starknetCore.l2ToL1Messages(msgHash) > 0;
  }
}
