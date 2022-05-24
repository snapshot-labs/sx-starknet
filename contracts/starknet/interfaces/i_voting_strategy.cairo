%lang starknet

from contracts.starknet.lib.eth_address import EthAddress
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace i_voting_strategy:
    func get_voting_power(
        block : felt,
        voter_address : EthAddress,
        params_len : felt,
        params : felt*,
        user_params_len : felt,
        user_params : felt*,
    ) -> (voting_power : Uint256):
    end
end
