// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";



interface IStarknetCore {
    /**
      Sends a message to an L2 contract.

      Returns the hash of the message.
    */
    function sendMessageToL2(
        uint256 to_address,
        uint256 selector,
        uint256[] calldata payload
    ) external returns (bytes32);

    /**
      Consumes a message that was sent from an L2 contract.

      Returns the hash of the message.
    */
    function consumeMessageFromL2(uint256 fromAddress, uint256[] calldata payload)
        external
        returns (bytes32);
}

abstract contract SnapshotXL1Voting is Ownable, Initializable {

    /*
    Contract that allows smart contract accounts to vote on SnapshotX, this should be deployed per dao that requires it 
        1) Tx is submitted to this contract containing proposal id, address of voter, choice, and signature. 
        2) send_message() function of the StarkNet core contract is called with a the voting contract as the "to" address and the function selector of vote() as an argument. 
        3) The StarkNet Sequencer automatically consumes the message and invokes the vote() function of the voting contract.
        4) signature verification and voting pows calculated and the vote is stored in the contract
        note: Until the sequencer is decentralized, we do not have censorship resistance here as the sequencer could choose to ignore the message. 
    */

    /// address of the L2 voting contract for this DAO 
    uint256 public votingContractL2;

    /*
    Selector for the L1 handler submit_vote in the vote authenticator, found via:
    from starkware.starknet.compiler.compile import get_selector_from_name
    print(get_selector_from_name('submit_vote'))
    */
    uint256 public constant L1_VOTE_HANDLER_SELECTOR = 1564459668182098068965022601237862430004789345537526898295871983090769185429; 

    struct Vote {
        uint256 vc_address; 
        uint256 proposalID;
        uint256 choice;
    }


    constructor(
        address _owner,
        uint256 _votingContractL2
    ) {
        bytes memory initParams = abi_encode(
            _owner,
            _votingContractL2
        )
        setUp(initParams);
    }

    function setUp(bytes memory initParams) public initializer {
        (
            address _owner,
            uint256 _votingContractL2
        ) = abi.decode(initParams, (address, uint256))
        __Ownable_init();
        transferOwnership(_owner);
        votingContractL2 = _votingContractL2;
    }



    function voteOnL1(uint256 proposalID, uint256 choice) external {
        uint256[] memory payload = new uint256[](1);
        payload[0] = proposalID;
        payload[1]

        starknetCore.sendMessageToL2(votingContractL2, L1_VOTE_HANDLER_SELECTOR, payload)
    } 


    function proposeOnL1(uint256 proposalID) virtual external;





}