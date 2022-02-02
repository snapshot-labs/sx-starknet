pragma solidity ^0.8.6;

//SPDX-License-Identifier: UNLICENSED

import "@gnosis.pm/zodiac/contracts/guard/Guardable.sol";

interface IStarknetCore {

    /**
      Consumes a message that was sent from an L2 contract.
      Returns the hash of the message.
    */   
    function consumeMessageFromL2(
        uint256 fromAddress,
        uint256[] calldata payload
    ) external returns (bytes32);

    function l2ToL1Messages(bytes32 msgHash) external view returns (uint256);
}

contract SnapshotXProposalRelayer is Guardable {

    // The StarkNet core contract.
    IStarknetCore public starknetCore;

    //address of the L2 end of the finalized proposal message bridge
    uint256 public decisionExecutorL2;

    event ChangedDecisionExecutorL2(uint256 _decisionExecutorL2);

    // constructor(address _starknetCore, uint256 _decisionExecutorL2) {
    //     starknetCore = IStarknetCore(_starknetCore);
    //     decisionExecutorL2 = _decisionExecutorL2;
    // }

    function setUpSnapshotXProposalRelayer(address _starknetCore, uint256 _decisionExecutorL2) internal {
        starknetCore = IStarknetCore(_starknetCore);
        decisionExecutorL2 = _decisionExecutorL2;
    }

    function changeDecisionExecutorL2(uint256 _decisionExecutorL2) public onlyOwner {
        decisionExecutorL2 = _decisionExecutorL2;
        emit ChangedDecisionExecutorL2(_decisionExecutorL2);
    } 

    //consumes finalized proposal message from L2 
    //This function should be called internally by the receiveProposal function 
    function _receiveFinalizedProposal(uint256 execution_details, uint256 hasPassed) internal {

        uint256[] memory payload = new uint256[](2);
        payload[0] = execution_details;
        payload[1] = hasPassed;

        //Returns the message Hash. If proposal execution message did not exist/not received yet, then this will fail
        starknetCore.consumeMessageFromL2(decisionExecutorL2, payload);
        //require(starknetCore.consumeMessageFromL2(decisionExecutorL2, payload), 'Incorrect payload or Finalized Proposal not yet received on L1');

    }

    //view function to check whether finalized proposal has been received on L1
    function isFinalizedProposalReceived(uint256 execution_details, uint256 hasPassed) external view returns (bool) {

        uint256[] memory payload = new uint256[](2);
        payload[0] = execution_details;
        payload[1] = hasPassed;

        bytes32 msgHash = keccak256(
            abi.encodePacked(decisionExecutorL2, uint256(uint160(msg.sender)), payload.length, payload)
        );       

        
        return starknetCore.l2ToL1Messages(msgHash) > 0;

    }


}