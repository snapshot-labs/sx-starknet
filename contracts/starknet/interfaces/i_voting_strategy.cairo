%lang starknet

from contracts.starknet.lib.eth_address import EthAddress
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace i_voting_strategy:
    func get_voting_power(
        timestamp : felt,
        voter_address : EthAddress,
        global_params_len : felt,
        global_params : felt*,
        params_len : felt,
        params : felt*,
    ) -> (voting_power : Uint256):
    end
end
