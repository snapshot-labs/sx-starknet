%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.starknet.lib.eth_address import EthAddress

@storage_var
func whitelist(address : EthAddress) -> (is_valid : felt):
end

@event
func whitelisted(address : EthAddress):
end

func register_whitelist{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        _whitelist_len : felt, _whitelist : felt*):
    if _whitelist_len == 0:
        return ()
    else:
        let address = EthAddress(_whitelist[0])
        # Add it to the whitelist
        whitelist.write(address, _whitelist[1])

        # Emit event
        whitelisted.emit(address)

        register_whitelist(_whitelist_len - 2, &_whitelist[2])
        return ()
    end
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        _whitelist_len : felt, _whitelist : felt*):
    register_whitelist(_whitelist_len, _whitelist)
    return ()
end

# Returns a voting power of 1 if the user is in the whitelist
@view
func get_voting_power{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        timestamp : felt, address : EthAddress, params_len : felt, params : felt*) -> (
        voting_power : Uint256):
    let (power) = whitelist.read(address)

    # `power` will be set to 1 if the address is whitelisted, and 0 otherwise
    # so using it as the `low` value for the `Uint256` is safe.
    return (Uint256(power, 0))
end
