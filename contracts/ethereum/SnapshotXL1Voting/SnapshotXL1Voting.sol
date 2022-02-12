/// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import './Interfaces/IStarknetCore.sol';

/**
 * @title Snapshot X L1 Voting contract
 * @author @Orland0x - <orlandothefraser@gmail.com>
 * @notice Allows EOAs and contract accounts to vote on Snapshot X with an L1 transaction, no signature needed.
 * @dev Work in progress
 */
contract SnapshotXL1Voting {
  /// The StarkNet core contract.
  IStarknetCore public immutable starknetCore;

  /// Address of the voting Authenticator contract that handles L1 votes, proposals, and delegations. This could be split into 3 separate contracts.
  uint256 public immutable votingAuthL1;

  /**
   * @dev Selector for the L1 handler submit_vote in the vote authenticator, found via:
   *      from starkware.starknet.compiler.compile import get_selector_from_name
   *      print(get_selector_from_name('submit_vote'))
   */
  uint256 private constant L1_VOTE_HANDLER =
    1564459668182098068965022601237862430004789345537526898295871983090769185429;

  /// @dev print(get_selector_from_name('submit_proposal'))
  uint256 private constant L1_PROPOSE_HANDLER =
    1604523576536829311415694698171983789217701548682002859668674868169816264965;

  /// @dev print(get_selector_from_name('delegate'))
  uint256 private constant L1_DELEGATE_HANDLER =
    1746921722015266013928822119890040225899444559222897406293768364420627026412;

  /* EVENTS */

  /**
   * @dev Emitted when a new L1 vote is submitted
   * @param votingContract Address of StarkNet voting contract
   * @param proposalID ID of the proposal the vote was submitted to
   * @param choice The vote choice {1,2,3}
   * @param voter Address of the voter
   */
  event L1VoteSubmitted(uint256 votingContract, uint256 proposalID, uint256 choice, address voter);

  /**
   * @dev Emitted when a new proposal is submitted via L1 vote
   * @param votingContract Address of voting contract for the relevant DAO on StarkNet
   * @param executionHash Hash of the proposal execution details
   * @param metadataHash Hash of the proposal metadata
   * @param domain Domain parameters for proposal
   * @param proposer Address of the proposer
   */
  event L1ProposalSubmitted(
    uint256 votingContract,
    uint256 executionHash,
    uint256 metadataHash,
    uint256 domain,
    address proposer
  );

  /// Vote object
  struct Vote {
    uint256 vc_address;
    uint256 proposalID;
    uint256 choice;
  }

  /**
   * @dev Constructor
   * @param _starknetCore Address of the StarkNet core contract
   * @param _votingAuthL1 Address of the StarkNet vote authenticator for L1 votes
   */
  constructor(address _starknetCore, uint256 _votingAuthL1) {
    starknetCore = IStarknetCore(_starknetCore);
    votingAuthL1 = _votingAuthL1;
  }

  /**
   * @dev Submit vote to Snapshot X proposal via L1 transaction (No signature needed)
   * @param votingContract Address of voting contract for the relevant DAO on StarkNet
   * @param proposalID ID of the proposal
   * @param choice The vote choice {1,2,3}
   */
  function voteOnL1(
    uint256 votingContract,
    uint256 proposalID,
    uint256 choice
  ) external {
    require((choice - 1) * (choice - 2) * (choice - 3) == 0, 'Invalid choice');
    uint256[] memory payload = new uint256[](4);
    payload[0] = votingContract;
    payload[1] = proposalID;
    payload[2] = choice;
    payload[3] = uint256(uint160(address(msg.sender)));
    //starknetCore.sendMessageToL2(votingAuthL1, L1_VOTE_HANDLER, payload);
    emit L1VoteSubmitted(votingContract, proposalID, choice, msg.sender);
  }

  /**
   * @dev Submit proposal to Snapshot X proposal via L1 transaction (No signature needed)
   * @param votingContract Address of voting contract for the relevant DAO on StarkNet
   * @param executionHash Hash of the proposal execution details
   * @param metadataHash Hash of the proposal metadata
   * @param domain Domain parameters for proposal
   */
  function proposeOnL1(
    uint256 votingContract,
    uint256 executionHash,
    uint256 metadataHash,
    uint256 domain
  ) external {
    uint256[] memory payload = new uint256[](5);
    payload[0] = votingContract;
    payload[1] = executionHash;
    payload[2] = metadataHash;
    payload[3] = domain;
    payload[4] = uint256(uint160(address(msg.sender)));
    //starknetCore.sendMessageToL2(votingAuthL1, L1_propose_HANDLER, payload);
    emit L1ProposalSubmitted(votingContract, executionHash, metadataHash, domain, msg.sender);
  }
}
