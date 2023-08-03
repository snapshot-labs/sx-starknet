#[starknet::contract]
mod SimpleQuorumExecutionStrategy {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::info;
    use zeroable::Zeroable;
    use sx::types::{Proposal, FinalizationStatus, ProposalStatus};

    #[storage]
    struct Storage {
        _quorum: u256
    }

    #[internal]
    fn initializer(ref self: ContractState, quorum: u256) {
        self._quorum.write(quorum);
    }

    #[internal]
    fn get_proposal_status(
        self: @ContractState,
        proposal: @Proposal,
        votes_for: u256,
        votes_against: u256,
        votes_abstain: u256
    ) -> ProposalStatus {
        let accepted = _quorum_reached(self._quorum.read(), votes_for, votes_against, votes_abstain)
            & _supported(votes_for, votes_against);

        let block_number = info::get_block_number();
        if *proposal.finalization_status == FinalizationStatus::Cancelled(()) {
            ProposalStatus::Cancelled(())
        } else if *proposal.finalization_status == FinalizationStatus::Executed(()) {
            ProposalStatus::Executed(())
        } else if block_number < *proposal.start_block_number {
            ProposalStatus::VotingDelay(())
        } else if block_number < *proposal.min_end_block_number {
            ProposalStatus::VotingPeriod(())
        } else if block_number < *proposal.max_end_block_number {
            if accepted {
                ProposalStatus::VotingPeriodAccepted(())
            } else {
                ProposalStatus::VotingPeriod(())
            }
        } else if accepted {
            ProposalStatus::Accepted(())
        } else {
            ProposalStatus::Rejected(())
        }
    }

    #[internal]
    fn _quorum_reached(
        quorum: u256, votes_for: u256, votes_against: u256, votes_abstain: u256
    ) -> bool {
        let total_votes = votes_for + votes_against + votes_abstain;
        total_votes >= quorum
    }

    #[internal]
    fn _supported(votes_for: u256, votes_against: u256) -> bool {
        votes_for > votes_against
    }
}
