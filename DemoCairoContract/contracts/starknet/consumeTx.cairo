%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_nn
from starkware.starknet.common.syscalls import get_caller_address

# A map from user (represented by account contract address)
# to their balance.
@storage_var
func param1_store(user : felt) -> (res : felt):
end

@storage_var
func param2_store(counter : felt) -> (res : felt):
end

@storage_var
func next_id_store() -> (res : felt):
end 

# An event emitted whenever increase_balance() is called.
# current_balance is the balance before it was increased.
@event
func tx_received(id: felt):
end

@external 
func receive_tx{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        param1 : felt, 
        param2 : felt
    ):
    assert_nn(param1)
    assert_nn(param2)

    let (next_id) =  next_id_store.read()

    param1_store.write(next_id, param1)
    param2_store.write(next_id, param2)

    tx_received.emit(next_id)

    next_id_store.write(next_id+1)

    return ()
end 

@view 
func get_next_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (
        next_id : felt
    ):
    let (next_id) =  next_id_store.read()
    return (next_id)
end


@view
func get_tx_params{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        id : felt
    ) -> (
        param1 : felt, 
        param2 : felt
    ):
    let (param1) = param1_store.read(id)
    let (param2) = param2_store.read(id)
    return (param1, param2)
end

