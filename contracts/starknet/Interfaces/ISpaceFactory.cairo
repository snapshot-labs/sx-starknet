%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace ISpacefactory {
    func deploy_space(
        public_key: felt,
        voting_delay: felt,
        min_voting_duration: felt,
        max_voting_duration: felt,
        proposal_threshold: Uint256,
        controller: felt,
        quorum: Uint256,
        voting_strategy_params_flat_len: felt,
        voting_strategy_params_flat: felt*,
        voting_strategies_len: felt,
        voting_strategies: felt*,
        authenticators_len: felt,
        authenticators: felt*,
        execution_strategy_len: felt,
        execution_strategy: felt*,
        metadata_uri_len: felt,
        metadata_uri: felt*,
    ) {
    }
}
