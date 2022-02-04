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
    Contract that allows smart contract accounts or EOAs to vote or create proposal on SnapshotX via an L1 transaction.
    There will be one instance of this contract that will be shared between all DAOs. 

    To vote via L1:    
        1) voteOnL1 is called by an EOA or a contract account with proposal id and choice as arguments. 
        2) send_message() function of the StarkNet core contract is called with the L1 vote authenticator as the "to" address and the function selector of submit_vote() as an argument.
            Additionally, the proposal id and the choice are submitted along with the address of the voter found from msg.sender. 
        3) The StarkNet Sequencer automatically consumes the message and invokes the submit_vote() @l1_handler function in the L1 vote authenticator.
        4) The vote is authenticated and stored in the voting contract for the DAO. 
        note: Until the sequencer is decentralized, we do not have censorship resistance here as the sequencer could choose to ignore the message. 
    */

    // The StarkNet core contract.
    IStarknetCore public starknetCore;

    /// address of the voting Authenticator contract that handles L1 votes
    uint256 public votingAuthL1;

    /*
    Selector for the L1 handler submit_vote in the vote authenticator, found via:
    from starkware.starknet.compiler.compile import get_selector_from_name
    print(get_selector_from_name('submit_vote'))
    */
    uint256 private constant L1_VOTE_HANDLER = 1564459668182098068965022601237862430004789345537526898295871983090769185429;

    // print(get_selector_from_name('submit_proposal'))
    uint256 private constant L1_PROPOSE_HANDLER = 1604523576536829311415694698171983789217701548682002859668674868169816264965;

    // print(get_selector_from_name('delegate'))
    uint256 private constant L1_DELEGATE_HANDLER = 1746921722015266013928822119890040225899444559222897406293768364420627026412;

    event L1VoteSubmitted(uint256 votingContract, uint256 proposalID, address voter, uint256 choice);
    event L1ProposalSubmitted(uint256 votingContract, uint256 executionHash, uint256 metadataHash, address proposer);

    struct Vote {
        uint256 vc_address; 
        uint256 proposalID;
        uint256 choice;
    }

    constructor(
        address _owner,
        address _starknetCore,
        uint256 _votingAuthL1
    ) {
        bytes memory initParams = abi.encode(
            _owner,
            _starknetCore,
            _votingAuthL1
        );
        setUp(initParams);
    }

    function setUp(bytes memory initParams) public initializer {
        (
            address _owner,
            address _starknetCore,
            uint256 _votingAuthL1
        ) = abi.decode(initParams, (address, address, uint256));

        transferOwnership(_owner);
        starknetCore = IStarknetCore(_starknetCore);
        votingAuthL1 = _votingAuthL1;
    }

    function voteOnL1(uint256 votingContract, uint256 proposalID, uint256 choice) external {
        uint256[] memory payload = new uint256[](4);
        payload[0] = votingContract;
        payload[1] = proposalID;
        payload[2] = uint256(uint160(address(msg.sender)));
        payload[3] = choice;
        starknetCore.sendMessageToL2(votingAuthL1, L1_VOTE_HANDLER, payload);

        emit L1VoteSubmitted(votingContract, proposalID, msg.sender, choice);
    } 

    function proposeOnL1(uint256 executionHash, uint256 metadataHash) virtual external;

    function delegateOnL1(uint256 proposalID, uint256 startBlockNumber, uint256 endBlockNumber) virtual external;



}


