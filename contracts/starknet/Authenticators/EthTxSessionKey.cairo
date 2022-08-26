%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math import assert_not_equal
from contracts.starknet.lib.general_address import Address
from contracts.starknet.lib.hash_array import HashArray
from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.eth_tx import EthTx
from contracts.starknet.lib.session_key import SessionKey

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    starknet_commit_address : felt
):
    EthTx.initializer(starknet_commit_address)
    return ()
end

# Performs EC recover on the Ethereum signature and stores the session key in a
# mapping indexed by the recovered Ethereum address
@external
func authorize_session_key_from_tx{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(eth_address : felt, session_public_key : felt, session_duration : felt):
    alloc_locals
    # Cast arguments to single array and hash them
    let (input_array : felt*) = alloc()
    assert input_array[0] = eth_address
    assert input_array[1] = session_public_key
    assert input_array[2] = session_duration
    let (hash) = HashArray.hash_array(3, input_array)

    # Checks that hash maches a commit and that the commit was created by the correct address
    EthTx.check_commit(hash, eth_address)

    # Register session key
    SessionKey.register_session_key(eth_address, session_public_key, session_duration)
    return ()
end
