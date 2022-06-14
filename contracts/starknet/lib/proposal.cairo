from starkware.cairo.common.uint256 import Uint256

struct Proposal:
    member execution_hash : Uint256
    member quorum : Uint256
    member snapshot_timestamp : felt
    member start_timestamp : felt
    member min_end_timestamp : felt
    member max_end_timestamp : felt
    member execution_params_hash : felt
    member ethereum_block_number : felt
    member executor : felt
end
