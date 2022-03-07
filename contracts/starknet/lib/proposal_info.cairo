from starkware.cairo.common.uint256 import Uint256
from contracts.starknet.lib.proposal import Proposal

struct ProposalInfo:
    member proposal : Proposal
    member power_for : Uint256
    member power_against : Uint256
    member power_abstain : Uint256
end
