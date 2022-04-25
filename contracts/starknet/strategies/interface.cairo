%lang starknet

from contracts.starknet.lib.eth_address import EthAddress
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IVotingStrategy:
    func get_voting_power(
        timestamp : felt, address : EthAddress, params_len : felt, params : felt*
    ) -> (voting_power : Uint256):
    end
end
