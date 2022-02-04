// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.6;

import "@gnosis.pm/zodiac/contracts/core/Module.sol";

import { SnapshotXProposalRelayer } from "./ProposalRelayer.sol";

contract SnapshotXL1Executor is Module, SnapshotXProposalRelayer {
    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;
    // keccak256(
    //     "EIP712Domain(uint256 chainId,address verifyingContract)"
    // );

    bytes32 public constant TRANSACTION_TYPEHASH = 0x72e9670a7ee00f5fbf1049b8c38e3f22fab7e9b85029e85cf9412f17fdd5c2ad;
    // keccak256(
    //     "Transaction(address to,uint256 value,bytes data,uint8 operation,uint256 nonce)"
    // );

    // counter that is incremented each time a proposal is recieved.
    uint256 public proposalIndex;

    //The state of a proposal index exists in one of the 5 categories. This can be queried using the getProposalState view function
    enum ProposalState {
        NotReceived,
        Received,
        Executing,
        Executed,
        Cancelled
    }

    struct ProposalExecution {
        bytes32[] txHashes; //array of Transaction Hashes for each transaction in the proposal
        uint256 executionCounter; //counter which stores the number of transaction in the proposal that have so far been executed. This ensures that transactions cannot be executed twice and that transactions are executed in the predefined order.
        bool cancelled;
        //timelock? (ignoring for now)
    }

    mapping(uint256 => ProposalExecution) public proposalIndexToProposalExecution;

    // ######## EVENTS ########

    event SnapshotXL1ExecutorSetUpComplete(
        address indexed initiator,
        address indexed _owner,
        address indexed _avatar,
        address _target,
        uint256 _decisionExecutorL2,
        address _starknetCore
    );

    event ProposalReceived(uint256 proposalIndex);
    event TransactionExecuted(uint256 proposalIndex, bytes32 txHash);
    event ProposalExecuted(uint256 proposalIndex);
    event ProposalCancelled(uint256 proposalIndex);

    // @dev
    // @param _owner
    // @param _avatar The address of the programmable ethereum account contract that this module is linked to. the contract must implement IAvatar.sol. Gnosis is safe is one implementation.
    // @param _target
    // @param _decisionExecutorL2 is the starknet address of the Decision Executor contract for this DAO. This contract will be the L2 end of the L2 -> L1 message bridge
    constructor(
        address _owner,
        address _avatar,
        address _target,
        address _starknetCore,
        uint256 _decisionExecutorL2
    ) {
        bytes memory initParams = abi.encode(_owner, _avatar, _target, _starknetCore, _decisionExecutorL2);
        setUp(initParams);
    }

    function setUp(bytes memory initParams) public override initializer {
        (address _owner, address _avatar, address _target, address _starknetCore, uint256 _decisionExecutorL2) = abi
            .decode(initParams, (address, address, address, address, uint256));

        __Ownable_init();
        transferOwnership(_owner);
        avatar = _avatar;
        target = _target;

        setUpSnapshotXProposalRelayer(_starknetCore, _decisionExecutorL2);

        emit SnapshotXL1ExecutorSetUpComplete(msg.sender, _owner, _avatar, _target, _decisionExecutorL2, _starknetCore);
    }

    //Consumes message from L2 containing finalized proposal, checks transaction hashes are valid, then stores transactions hashes
    function receiveProposal(
        uint256 executionDetails,
        uint256 hasPassed,
        bytes32[] memory txHashes
    ) public {
        //External call will fail if finalized proposal message was not recieved on L1.
        _recieveFinalizedProposal(executionDetails, hasPassed);

        //Check that proposal passed
        require(hasPassed != 0, "Proposal did not pass");

        //check that execution details are valid
        require(bytes32(executionDetails) == keccak256(abi.encode(txHashes)), "Invalid execution");

        proposalIndexToProposalExecution[proposalIndex].txHashes = txHashes;
        proposalIndex += 1;

        emit ProposalReceived(proposalIndex);
    }

    //Test function to cause an equivalent state change to recieveProposal without having to consume a starknet message.
    function recieveProposalTest(
        uint256 executionDetails,
        uint256 hasPassed,
        bytes32[] memory _txHashes
    ) public {
        //Check that proposal passed
        require(hasPassed == 1, "Proposal did not pass");

        //Check proposal contains at least one transaction
        require(_txHashes.length > 0, "proposal must contain transactions");

        //check that transactions are valid
        require(bytes32(executionDetails) == keccak256(abi.encode(_txHashes)), "Invalid execution");

        proposalIndexToProposalExecution[proposalIndex].txHashes = _txHashes;

        proposalIndex++; //uint256(0); // Very weird error here: AssertionError: Expected "1" to be equal 0 when I increment by 1. ignored for now

        emit ProposalReceived(proposalIndex);
    }

    /// @dev Cancels a proposal.
    /// @param _proposalIndexes array of proposals to cancel.
    function cancelProposals(uint256[] memory _proposalIndexes) public onlyOwner {
        for (uint256 i = 0; i < _proposalIndexes.length; i++) {
            require(
                getProposalState(_proposalIndexes[i]) != ProposalState.NotReceived,
                "Proposal not recieved, nothing to cancel"
            );

            require(
                getProposalState(_proposalIndexes[i]) != ProposalState.Executed,
                "Execution completed, nothing to cancel"
            );

            require(
                proposalIndexToProposalExecution[_proposalIndexes[i]].cancelled == false,
                "proposal is already canceled"
            );

            //to cancel a proposal, we can set the execution counter for the proposal to the number of transactions in the proposal.
            //We must also set a boolean in the Proposal Execution struct to true, without this there would be no way for the state to differentiate between a cancelled and an executed proposal.
            proposalIndexToProposalExecution[_proposalIndexes[i]].executionCounter = proposalIndexToProposalExecution[
                _proposalIndexes[i]
            ].txHashes.length;
            proposalIndexToProposalExecution[_proposalIndexes[i]].cancelled = true;
            emit ProposalCancelled(_proposalIndexes[i]);
        }
    }

    function executeProposalTx(
        uint256 _proposalIndex,
        address target,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public {
        bytes32 txHash = getTransactionHash(target, value, data, operation);

        //If all the Txs have been executed then the executionCounter will be exceed the length of the txHash array so the state look up will return nothing
        require(
            proposalIndexToProposalExecution[_proposalIndex].txHashes[
                proposalIndexToProposalExecution[_proposalIndex].executionCounter
            ] == txHash,
            "Invalid transaction or invalid transaction order"
        );

        proposalIndexToProposalExecution[_proposalIndex].executionCounter++;

        require(exec(target, value, data, operation), "Module transaction failed");

        emit TransactionExecuted(_proposalIndex, txHash);

        //if final transaction, emit ProposalExecuted event - could remove to reduce gas costs a bit and infer offchain
        if (getProposalState(_proposalIndex) == ProposalState.Executed) {
            emit ProposalExecuted(_proposalIndex);
        }
    }

    //Wrapper function around executeProposalTx to execute all transactions in a proposal with a single transaction.
    //Will reach the block gas limit if too many/large transactions are included.
    function executeProposalTxBatch(
        uint256 _proposalIndex,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory data,
        Enum.Operation[] memory operations
    ) public {
        //execute each transaction individually
        for (uint256 i = 0; i < targets.length; i++) {
            executeProposalTx(_proposalIndex, targets[i], values[i], data[i], operations[i]);
        }
    }

    //###### VIEW FUNCTIONS ######

    function getProposalState(uint256 _proposalIndex) public view returns (ProposalState) {
        ProposalExecution storage proposalExecution = proposalIndexToProposalExecution[_proposalIndex];
        if (proposalExecution.txHashes.length == 0) {
            return ProposalState.NotReceived;
        } else if (proposalExecution.cancelled) {
            return ProposalState.Cancelled;
        } else if (proposalExecution.executionCounter == 0) {
            return ProposalState.Received;
        } else if (proposalExecution.txHashes.length == proposalExecution.executionCounter) {
            return ProposalState.Executed;
        } else {
            return ProposalState.Executing;
        }
    }

    function getNumOfTxInProposal(uint256 _proposalIndex) public view returns (uint256) {
        return proposalIndexToProposalExecution[_proposalIndex].txHashes.length;
    }

    //returns hash of transaction at specified index in array.
    //One can iterate through this up till isProposalExecuted to obtain all the Tx hashes in the proposal
    function getTxHash(uint256 _proposalIndex, uint256 txIndex) public view returns (bytes32) {
        require(_proposalIndex < proposalIndex, "Invalid Proposal Index");
        require(txIndex < proposalIndexToProposalExecution[_proposalIndex].txHashes.length);
        return proposalIndexToProposalExecution[_proposalIndex].txHashes[txIndex];
    }

    //returns true if transaction specified by its index is executed
    function isTxExecuted(uint256 _proposalIndex, uint256 txIndex) public view returns (bool) {
        require(_proposalIndex < proposalIndex, "Invalid Proposal Index");
        require(txIndex < proposalIndexToProposalExecution[_proposalIndex].txHashes.length);
        return proposalIndexToProposalExecution[_proposalIndex].executionCounter > txIndex;
    }

    /// @dev Generates the data for the module transaction hash (required for signing)
    function generateTransactionHashData(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 nonce
    ) public view returns (bytes memory) {
        uint256 chainId = block.chainid;
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, chainId, this));
        bytes32 transactionHash = keccak256(
            abi.encode(TRANSACTION_TYPEHASH, to, value, keccak256(data), operation, nonce)
        );
        return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator, transactionHash);
    }

    function getTransactionHash(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public view returns (bytes32) {
        return keccak256(generateTransactionHashData(to, value, data, operation, 0));
    }
}
