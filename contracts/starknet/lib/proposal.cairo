from starkware.cairo.common.uint256 import Uint256

struct Proposal:
    member quorum : Uint256
    member snapshot_timestamp : felt
    member start_timestamp : felt
    member min_end_timestamp : felt
    member max_end_timestamp : felt
    member executor : felt
    member execution_hash : felt
end
