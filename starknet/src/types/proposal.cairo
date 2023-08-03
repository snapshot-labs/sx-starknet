use clone::Clone;
use serde::Serde;
use starknet::ContractAddress;
use sx::types::{FinalizationStatus, UserAddress};

/// NOTE: Using u64 for block numbers instead of u32 which we use in sx-evm. can change if needed.
#[derive(Clone, Drop, Serde, PartialEq, starknet::Store)]
struct Proposal {
    snapshot_block_number: u64,
    start_block_number: u64,
    min_end_block_number: u64,
    max_end_block_number: u64,
    execution_payload_hash: felt252,
    execution_strategy: ContractAddress,
    author: UserAddress,
    finalization_status: FinalizationStatus,
    active_voting_strategies: u256
}
