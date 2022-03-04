from starkware.cairo.common.uint256 import Uint256

struct ProposalInfo:
    member execution_hash : felt  # TODO: Use Hash type
    member start_block : felt
    member end_block : felt
    member power_for : Uint256
    member power_against : Uint256
    member power_abstain : Uint256
end
