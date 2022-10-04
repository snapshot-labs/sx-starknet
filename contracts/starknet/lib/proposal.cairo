from starkware.cairo.common.uint256 import Uint256

struct Proposal {
    quorum: Uint256,
    packed_timestamps: felt,
    executor: felt,
    execution_hash: felt,
}
