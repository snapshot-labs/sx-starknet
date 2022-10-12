%lang starknet

from contracts.starknet.lib.general_address import Address
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IVotingStrategy {
    func getVotingPower(
        timestamp: felt,
        voter_address: Address,
        params_len: felt,
        params: felt*,
        user_params_len: felt,
        user_params: felt*,
    ) -> (voting_power: Uint256) {
    }
}
