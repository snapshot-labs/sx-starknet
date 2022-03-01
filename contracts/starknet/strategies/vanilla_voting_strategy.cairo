%lang starknet

from starkware.cairo.common.uint256 import Uint256
from contracts.starknet.lib.types import EthAddress

# Returns a voting power of 1 for every address it is queried with.
@view
func get_voting_power{range_check_ptr}(
        block : felt, address : EthAddress, params_len : felt, params : felt*) -> (
        voting_power : Uint256):
    tempvar voting_power : Uint256 = Uint256(1, 0)
    return (voting_power)
end
