%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
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

# Calls get_session_key with the ethereum address (calldata[0]) to check that a session is active.
# If so, perfoms stark signature verification to check the sig is valid. If so calls execute with the payload.
@external
func authenticate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sig_len : felt,
    sig : felt*,
    session_public_key : felt,
    target : felt,
    function_selector : felt,
    calldata_len : felt,
    calldata : felt*,
):
    # TO DO: Verify stark signature

    # Check session key is active
    let (eth_address) = SessionKey.get_session_key(session_public_key)

    # Check user's address is equal to the owner of the session key
    with_attr error_message("Invalid Ethereum address"):
        assert calldata[0] = eth_address
    end

    # foreward payload to target
    execute(target, function_selector, calldata_len, calldata)

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

# Receives hash from StarkNet commit contract and stores it in state.
@l1_handler
func commit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    from_address : felt, sender : felt, hash : felt
):
    EthTx.commit(from_address, sender, hash)
    return ()
end
