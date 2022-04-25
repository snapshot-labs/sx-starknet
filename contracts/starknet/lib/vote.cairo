%lang starknet

from contracts.starknet.lib.eth_address import EthAddress
from starkware.cairo.common.uint256 import Uint256

struct Vote:
    member voting_power : felt
end
