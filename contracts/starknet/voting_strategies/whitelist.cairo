%lang starknet

from starkware.cairo.common.uint256 import Uint256, uint256_check
from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.starknet.lib.eth_address import EthAddress

@storage_var
func whitelist(address : EthAddress) -> (voting_power : Uint256):
end

@event
func whitelisted(address : EthAddress, voting_power : Uint256):
end

func register_whitelist{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    _whitelist_len : felt, _whitelist : felt*
):
    if _whitelist_len == 0:
        return ()
    else:
        let address = EthAddress(_whitelist[0])
        # Add it to the whitelist
        let voting_power = Uint256(_whitelist[1], _whitelist[2])

        with_attr error_message("Invalid uin256"):
            uint256_check(voting_power)
        end

        whitelist.write(address, voting_power)

        # Emit event
        whitelisted.emit(address, voting_power)

        register_whitelist(_whitelist_len - 3, &_whitelist[3])
        return ()
    end
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    _whitelist_len : felt, _whitelist : felt*
):
    register_whitelist(_whitelist_len, _whitelist)
    return ()
end

@view
func get_voting_power{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    block : felt,
    voter_address : EthAddress,
    global_params_len : felt,
    global_params : felt*,
    params_len : felt,
    params : felt*,
) -> (voting_power : Uint256):
    let (power) = whitelist.read(address)

    # `power` will be set to 0 if other is not whitelisted
    return (power)
end
