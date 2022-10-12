%lang starknet

from starkware.cairo.common.uint256 import Uint256, uint256_check
from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.starknet.lib.general_address import Address

//
// @title Whitelist Voting Strategy
// @author SnapshotLabs
// @notice Contract to allow a whitelist to be used to compute voting power for each user
//

// @dev Mapping between each address in the whitelist and the voting power assigned to them
@storage_var
func whitelist(address: Address) -> (voting_power: Uint256) {
}

@event
func whitelisted(address: Address, voting_power: Uint256) {
}

// @dev Constructor
// @param whitelist Array containing the whitelist
// @notice The whitelist array should be as follows:
//    whitelist[0]: The 1st user's address
//    whitelist[1]: The low 128 bits of the 1st user's voting power
//    whitelist[2]: The high 128 bits of the 1st user's voting power
//    whitelist[4]: The 2nd user's address
//    etc...
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    whitelist_len: felt, whitelist: felt*
) {
    _register_whitelist(whitelist_len, whitelist);
    return ();
}

// @dev Returns the voting power for a user obtained from the whitelist
// @param timestamp The snapshot timestamp
// @param voter_address The address of the user
// @param params Empty array
// @param user_params Empty array
// @return voting_power The voting power of the user
@view
func get_voting_power{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    timestamp: felt,
    voter_address: Address,
    params_len: felt,
    params: felt*,
    user_params_len: felt,
    user_params: felt*,
) -> (voting_power: Uint256) {
    let (power) = whitelist.read(voter_address);
    // `power` will be set to 0 if voter is not whitelisted
    return (power,);
}

func _register_whitelist{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    _whitelist_len: felt, _whitelist: felt*
) {
    if (_whitelist_len == 0) {
        return ();
    } else {
        let address = Address(_whitelist[0]);
        // Add it to the whitelist
        let voting_power = Uint256(_whitelist[1], _whitelist[2]);
        with_attr error_message("Whitelist: Invalid uint256 for voting power") {
            uint256_check(voting_power);
        }
        whitelist.write(address, voting_power);
        whitelisted.emit(address, voting_power);
        register_whitelist(_whitelist_len - 3, &_whitelist[3]);
        return ();
    }
}
