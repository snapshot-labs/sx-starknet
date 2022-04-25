%lang starknet

from contracts.starknet.lib.eth_address import EthAddress
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IExecutionStrategy:
    func execute(
        proposal_outcome : felt,
        execution_hash : Uint256,
        execution_params_len : felt,
        execution_params : felt*,
    ):
    end
end
