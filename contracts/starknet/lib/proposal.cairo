from contracts.starknet.lib.eth_address import EthAddress
from starkware.cairo.common.uint256 import Uint256

struct Proposal:
    member execution_hash : Uint256  # TODO: Use Hash type
    member start_timestamp : felt
    member end_timestamp : felt
    member ethereum_block_number : felt
end
