from starkware.cairo.common.uint256 import Uint256
from contracts.starknet.lib.proposal import Proposal

struct ProposalInfo:
    member proposal : Proposal
    member power_for : felt
end
