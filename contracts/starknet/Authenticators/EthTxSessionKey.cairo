%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from contracts.starknet.lib.hash_array import HashArray
from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.eth_tx import EthTx
from contracts.starknet.lib.session_key import SessionKey
from contracts.starknet.lib.stark_eip191 import StarkEIP191

# getSelectorFromName("propose")
const PROPOSAL_SELECTOR = 0x1bfd596ae442867ef71ca523061610682af8b00fc2738329422f4ad8d220b81
# getSelectorFromName("vote")
const VOTE_SELECTOR = 0x132bdf85fc8aa10ac3c22f02317f8f53d4b4f52235ed1eabb3a4cbbe08b5c41

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
func authenticate{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*
}(
    r : felt,
    s : felt,
    salt : felt,
    target : felt,
    function_selector : felt,
    calldata_len : felt,
    calldata : felt*,
    session_public_key : felt,
):
    # Check session key is active
    let (eth_address) = SessionKey.get_owner(session_public_key)

    # Check user's address is equal to the owner of the session key
    with_attr error_message("Invalid Ethereum address"):
        assert calldata[0] = eth_address
    end

    # Check signature with session key
    if function_selector == PROPOSAL_SELECTOR:
        StarkEIP191.verify_propose_sig(
            r, s, salt, target, calldata_len, calldata, session_public_key
        )
    else:
        if function_selector == VOTE_SELECTOR:
            StarkEIP191.verify_vote_sig(
                r, s, salt, target, calldata_len, calldata, session_public_key
            )
        else:
            # Invalid selector
            return ()
        end
    end

    # Call the contract
    execute(target, function_selector, calldata_len, calldata)

    return ()
end

@external
func authorize_session_key_with_tx{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(eth_address : felt, session_public_key : felt, session_duration : felt):
    SessionKey.authorize_with_tx(eth_address, session_public_key, session_duration)
    return ()
end

# Checks signature is valid and if so, removes session key for user
@external
func revoke_session_key_with_session_key_sig{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*
}(r : felt, s : felt, salt : felt, session_public_key : felt):
    SessionKey.revoke_with_session_key_sig(r, s, salt, session_public_key)
    return ()
end

@external
func revoke_session_key_with_owner_tx{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(session_public_key : felt):
    SessionKey.revoke_with_owner_tx(session_public_key)
    return ()
end

# Public view function for checking a session key
@view
func get_session_key_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    session_public_key : felt
) -> (eth_address : felt):
    let (eth_address) = SessionKey.get_owner(session_public_key)
    return (eth_address)
end

# Receives hash from StarkNet commit contract and stores it in state.
@l1_handler
func commit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    from_address : felt, sender : felt, hash : felt
):
    EthTx.commit(from_address, sender, hash)
    return ()
end
