%lang starknet

from starkware.cairo.common.uint256 import Uint256
from contracts.starknet.lib.eth_address import EthAddress

# Returns a voting power of 1 for every address it is queried with.
@view
func get_voting_power{range_check_ptr}(
    block : felt,
    voter_address : EthAddress,
    params_len : felt,
    params : felt*,
    user_params_len : felt,
    user_params : felt*,
) -> (voting_power : Uint256):
    return (Uint256(1, 0))
end
