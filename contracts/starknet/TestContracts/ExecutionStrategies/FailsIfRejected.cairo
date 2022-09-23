%lang starknet

from starkware.cairo.common.uint256 import Uint256
from contracts.starknet.lib.proposal_outcome import ProposalOutcome

# Throws if `proposal_outcome` is `REJECTED`.
@external
func execute{syscall_ptr : felt*}(
    proposal_outcome : felt, execution_params_len : felt, execution_params : felt*
):
    if proposal_outcome == ProposalOutcome.REJECTED:
        with_attr error_message("Proposal was rejected"):
            assert 1 = 0
        end
    end
    return ()
end
