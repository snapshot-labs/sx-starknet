%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_nn
from starkware.starknet.common.syscalls import get_caller_address

@storage_var
func owner_account_store() -> (key : felt):
end

@storage_var
func choices_store(proposal_id : felt, choice : felt) -> (num : felt):
end 

@event 
func vote_received(proposal_id : felt, address : felt, choice : felt):
end 

@constructor 
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        owner_account : felt
    ):
    owner_account_store.write(owner_account)
    return ()
end 

@view 
func get_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }() -> (
        owner_account : felt
    ):
    let (owner_account) = owner_account_store.read()
    return (owner_account)
end

@external 
func change_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        new_owner_account : felt
    ):
    let (caller_account) = get_caller_address()
    let (owner_account) = owner_account_store.read()
    assert caller_account = owner_account
    owner_account_store.write(new_owner_account)  

    return ()    
end

@external 
func vote{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        proposal_id : felt,
        address : felt,
        choice : felt,
        signature : felt
    ):
    
    #ensures choice is 1 or 2 or 3 only
    assert (choice-1)*(choice-2)*(choice-3) = 0

    let (num_choice) = choices_store.read(proposal_id, choice)

    choices_store.write(proposal_id, choice, num_choice+1) 

    vote_received.emit(proposal_id, address, choice) 

    return ()
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



