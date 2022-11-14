// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_nn_le

from contracts.starknet.lib.general_address import Address
from contracts.starknet.lib.merkle import Merkle

//
// @title Merkle Whitelist Voting Strategy
// @author SnapshotLabs
// @notice Contract to allow a merkle tree based whitelist to be used to compute voting power for each user
//

// @dev Returns the voting power for a user obtained from the whitelist
// @param timestamp The snapshot timestamp (not used)
// @param voter_address The address of the user
// @param params Configuration parameter array that is the same for every voter in the proposal. Should be as follows:
//      params[0] = The merkle root of the whitelist data, should be computed off-chain
// @param user_params Array containing the leaf and merkle proof data. Should be as follows:
//      user_params[0] = address of the whitelisted user
//      user_params[1] = Low 128 bits of the voting power of the user
//      user_params[2] = High 128 bits of the voting power of the user
// @return voting_power The voting power of the user as a Uint256
@view
func getVotingPower{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    timestamp: felt,
    voter_address: Address,
    params_len: felt,
    params: felt*,
    user_params_len: felt,
    user_params: felt*,
) -> (voting_power: Uint256) {
    alloc_locals;

    with_attr error_message("MerkleWhitelist: Invalid parameters supplied") {
        assert_nn_le(3, user_params_len);
    }

    // Extracting leaf data from user params array
    let (leaf: felt*) = alloc();
    let leaf_len = 3;
    memcpy(leaf, user_params, leaf_len);

    // Checking that the leaf corresponds to the voter's address
    with_attr error_message("MerkleWhitelist: Invalid proof supplied") {
        // The address resides at the beginning of the leaf data array
        assert leaf[0] = voter_address.value;
    }

    // Extracting proof from user params array
    let (proof: felt*) = alloc();
    let proof_len = user_params_len - leaf_len;
    memcpy(proof, user_params + leaf_len, proof_len);

    // Extracting merkle root from params array
    let merkle_root = params[0];

    // Checking the merkle proof
    Merkle.assert_valid_leaf(merkle_root, leaf_len, leaf, proof_len, proof);

    // Extract voting power from leaf and cast to Uint256
    let voting_power = Uint256(leaf[1], leaf[2]);

    return (voting_power,);
}
