%lang starknet

from starkware.cairo.common.uint256 import Uint256

struct Vote {
    choice: felt,
    voting_power: Uint256,
}
