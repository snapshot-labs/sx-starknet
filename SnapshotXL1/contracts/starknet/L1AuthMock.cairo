%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.hash import hash2
from starkware.starknet.common.syscalls import (get_caller_address, get_block_number, get_block_timestamp)


#Demo contract to test voting on snapshot X via the L1 voting contract. 
#aside from the view functions, this contract cannot be called directly, but only via the methods in the L1 voting contract. 
#No Double voting prevention 

const L1_VOTING_CONTRACT = (0x1234)

#mapping stores 1 if the proposal has been initialized, otherwise 0
@storage_var 
func proposal_id_store(proposal_id : felt) -> (bool : felt):
end

#double mapping that stores a counter for each vote type (1,2,3) for every proposal
@storage_var
func choices_store(proposal_id : felt, choice : felt) -> (num : felt):
end 

#event emitted after each proposal is created
@event 
func proposal_created_from_L1(proposal_id : felt, proposer_address : felt):
end

#event emitted after ech vote is received 
@event 
func vote_received_from_L1(proposal_id : felt, voter_address : felt, choice : felt):
end 

#Submit proposal from L1 voting contract
@l1_handler 
func submit_proposal{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr 
    }(
        from_address : felt, 
        vc_address : felt,
        execution_hash : felt, 
        metadata_hash : felt
    ):

    assert from_address = L1_VOTING_CONTRACT 
    #the proposal id is the hash of the execution_hash and the metadata_hash 
    let (proposal_id) = hash2{hash_ptr=pedersen_ptr}(execution_hash, metadata_hash)
    let (init) = proposal_id_store.read(proposal_id)
    #check that the proposal has not already been initialized
    assert init = 0 
    #initialize proposal
    proposal_id_store.write(proposal_id, 1)
    let (caller) = get_caller_address()
    #emit proposal creation event 
    proposal_created_from_L1.emit(proposal_id, caller)

    #The voting contract would be called to store the proposal
    return ()
end 

#Submit vote from L1 voting contract
@l1_handler 
func submit_vote{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr 
    }(
        from_address : felt, 
        vc_address : felt,
        proposal_id : felt, 
        address : felt,
        choice : felt 
    ): 

    assert from_address = L1_VOTING_CONTRACT
    #ensures choice is 1 or 2 or 3 only
    assert (choice-1)*(choice-2)*(choice-3) = 0
    let (num_choice) = choices_store.read(proposal_id, choice)
    choices_store.write(proposal_id, choice, num_choice+1) 
    vote_received_from_L1.emit(proposal_id, address, choice)

    #The voting contract would be called to store the vote

    return ()
end 

@view
func get_proposal_id{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        execution_hash : felt, 
        metadata_hash : felt 
    ) -> (
        proposal_id : felt
    ):
    let (proposal_id) = hash2{hash_ptr=pedersen_ptr}(execution_hash, metadata_hash)
    return (proposal_id)
end

@view 
func get_num_choice{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        proposal_id : felt,
        choice : felt
    ) -> (
        num : felt 
    ):
    let (num_choice) = choices_store.read(proposal_id, choice)
    return (num_choice)   

end