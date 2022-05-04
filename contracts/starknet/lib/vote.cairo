%lang starknet

from starkware.cairo.common.uint256 import Uint256

struct Vote:
    member choice : felt
    member voting_power : Uint256
end
