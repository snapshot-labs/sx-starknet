use clone::Clone;
use serde::Serde;
use starknet::ContractAddress;
use sx::types::FinalizationStatus;

/// NOTE: Using u64 for timestamps instead of u32 which we use in sx-evm. can change if needed.
#[derive(Clone, Drop, Serde, PartialEq, starknet::Store)]
struct Proposal {
    snapshot_timestamp: u64,
    start_timestamp: u64,
    min_end_timestamp: u64,
    max_end_timestamp: u64,
    execution_payload_hash: felt252,
    execution_strategy: ContractAddress,
    author: ContractAddress,
    finalization_status: FinalizationStatus,
    active_voting_strategies: u256
}
