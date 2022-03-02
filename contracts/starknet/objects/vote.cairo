%lang starknet

from contracts.starknet.lib.types import EthAddress

struct Vote:
    member choice : felt
    member eth_address : EthAddress
    member voting_power : felt
end
