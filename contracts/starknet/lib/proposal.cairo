from starkware.cairo.common.uint256 import Uint256

struct Proposal {
    quorum: Uint256,
    snapshot_timestamp: felt,
    start_timestamp: felt,
    min_end_timestamp: felt,
    max_end_timestamp: felt,
    execution_strategy: felt,
    execution_hash: felt,
}
