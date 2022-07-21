%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from contracts.starknet.lib.general_address import Address
from starkware.cairo.common.uint256 import Uint256
from contracts.starknet.VotingStrategies.single_slot_proof import single_slot_proof

#
# Template Voting Strategy for use with the single slot proof library
#

@view
func get_voting_power{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(
    timestamp : felt,
    voter_address : Address,
    params_len : felt,
    params : felt*,
    user_params_len : felt,
    user_params : felt*,
) -> (voting_power : Uint256):
    let (storage_value) = single_slot_proof.get_storage_value(
        timestamp, voter_address, params_len, params, user_params_len, user_params
    )

    # Perform arbitrary logic on the storage value returned here, eg sqrt, cutoff, inverse etc...
    # eg 1 to 1 mapping:
    let voting_power = storage_value

    return (voting_power)
end
