%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.starknet.lib.general_address import Address
from contracts.starknet.lib.uint256_utils import Uint256Utils

@storage_var
func whitelist(address: Address) -> (voting_power: Uint256) {
}

@event
func whitelisted(address: Address, voting_power: Uint256) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    _whitelist_len: felt, _whitelist: felt*
) {
    register_whitelist(_whitelist_len, _whitelist);
    return ();
}

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

    // `power` will be set to 0 if other is not whitelisted
    return (power,);
}

func register_whitelist{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    _whitelist_len: felt, _whitelist: felt*
) {
    if (_whitelist_len == 0) {
        return ();
    } else {
        let address = Address(_whitelist[0]);
        // Add it to the whitelist
        let voting_power = Uint256(_whitelist[1], _whitelist[2]);

        Uint256Utils.assert_valid_uint256(voting_power);

        whitelist.write(address, voting_power);

        // Emit event
        whitelisted.emit(address, voting_power);

        register_whitelist(_whitelist_len - 3, &_whitelist[3]);
        return ();
    }
}
