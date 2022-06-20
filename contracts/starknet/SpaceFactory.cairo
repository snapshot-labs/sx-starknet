%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import deploy

@storage_var
func salt() -> (value : felt):
end

@storage_var
func space_class_hash_store() -> (value : felt):
end

@event
func space_deployed(address : felt):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    space_class_hash : felt
):
    space_class_hash_store.write(space_class_hash)
    return ()
end

@external
func deploy_space{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    calldata_len : felt, calldata : felt*
):
    let (current_salt) = salt.read()
    let (space_class_hash) = space_class_hash_store.read()
    let (space_address) = deploy(
        class_hash=space_class_hash,
        contract_address_salt=current_salt,
        constructor_calldata_size=calldata_len,
        constructor_calldata=calldata,
    )
    salt.write(value=current_salt + 1)
    space_deployed.emit(space_address)
    return ()
end
