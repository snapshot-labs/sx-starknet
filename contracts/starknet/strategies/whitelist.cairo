%lang starknet

from starkware.cairo.common.uint256 import Uint256
from contracts.starknet.lib.eth_address import EthAddress
from starkware.cairo.common.cairo_builtins import HashBuiltin

@storage_var
func whitelist(address : EthAddress) -> (is_valid : felt):
end

@event
func whitelisted(address : felt):
end

func register_whitelist{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    _whitelist_len : felt, _whitelist : felt*
):
    if _whitelist_len == 0:
        return ()
    else:
        # Add it to the whitelist
        whitelist.write(EthAddress(_whitelist[0]), 1)

        # Emit event
        whitelisted.emit(_whitelist[0])

        if _whitelist_len == 1:
            return ()
        else:
            register_whitelist(_whitelist_len - 1, &_whitelist[1])
            return ()
        end
    end
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    _whitelist_len : felt, _whitelist : felt*
):
    register_whitelist(_whitelist_len, _whitelist)
    return ()
end

# Returns a voting power of 1 if the user is in the whitelist
@view
func get_voting_power{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    timestamp : felt, address : EthAddress, params_len : felt, params : felt*
) -> (voting_power : Uint256):
    let (is_valid) = whitelist.read(address)

    with_attr error_message("Voter not whitelisted"):
        assert is_valid = 1
    end

    return (Uint256(1, 0))
end
