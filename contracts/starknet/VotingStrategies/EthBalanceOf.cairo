# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

from contracts.starknet.lib.general_address import Address
from contracts.starknet.lib.single_slot_proof import SingleSlotProof

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    fact_registry_address : felt, l1_headers_store_address : felt
):
    SingleSlotProof.initializer(fact_registry_address, l1_headers_store_address)
    return ()
end

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
    let (voting_power) = SingleSlotProof.get_storage_slot(
        timestamp, voter_address, params_len, params, user_params_len, user_params
    )
    return (voting_power)
end
