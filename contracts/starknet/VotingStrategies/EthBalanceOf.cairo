// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from contracts.starknet.lib.general_address import Address
from contracts.starknet.lib.single_slot_proof import SingleSlotProof

//
// @title Ethereum Balance Of Voting Strategy
// @author SnapshotLabs
// @notice Contract to allow Ethereum token balances to be used as voting power
//

// @dev Constructor
// @param fact_registry_address Address of the Fossil fact registry contract
// @param l1_headers_store_address Address of the Fossil L1 headers store contract
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    fact_registry_address: felt, l1_headers_store_address: felt
) {
    SingleSlotProof.initializer(fact_registry_address, l1_headers_store_address);
    return ();
}

// @dev Returns the voting power for a user
// @param timestamp The snapshot timestamp
// @param voter_address The address of the user
// @param params Configuration parameter array that is the same for every voter in the proposal. Should be as follows:
//      params[0] = The address of the Ethereum token contract
//      params[1] = The index of the slot within the token contract where the balances[_address] mapping resides
// @param user_params Array containing storage proofs for the users balance within the token contract
// @return voting_power The value of the balances[_address] mapping corresponding to the user's address
@view
func getVotingPower{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    timestamp: felt,
    voter_address: Address,
    params_len: felt,
    params: felt*,
    user_params_len: felt,
    user_params: felt*,
) -> (voting_power: Uint256) {
    let (voting_power) = SingleSlotProof.get_storage_slot(
        timestamp, voter_address.value, params_len, params, user_params_len, user_params
    );
    return (voting_power,);
}
