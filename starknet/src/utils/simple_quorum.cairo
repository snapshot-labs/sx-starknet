use starknet::info;
use sx::types::{Proposal, FinalizationStatus, ProposalStatus};

/// Returns the status of a proposal, according to a 'Simple Quorum' rule.
/// A proposal is accepted if the for votes exceeds the against votes and a 
/// quorum of (for + abstain) is reached.
fn get_proposal_status(
    proposal: @Proposal, quorum: u256, votes_for: u256, votes_against: u256, votes_abstain: u256,
) -> ProposalStatus {
    let quorum_reached = votes_for + votes_abstain >= quorum;
    let supported = votes_for > votes_against;
    let accepted = quorum_reached && supported;

    let timestamp = info::get_block_timestamp().try_into().unwrap();
    if *proposal.finalization_status == FinalizationStatus::Cancelled(()) {
        ProposalStatus::Cancelled(())
    } else if *proposal.finalization_status == FinalizationStatus::Executed(()) {
        ProposalStatus::Executed(())
    } else if timestamp < *proposal.start_timestamp {
        ProposalStatus::VotingDelay(())
    } else if (timestamp < *proposal.min_end_timestamp) {
        ProposalStatus::VotingPeriod(())
    } else if timestamp < *proposal.max_end_timestamp {
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

#[cfg(test)]
mod tests {
    use super::{get_proposal_status};
    use sx::types::{Proposal, FinalizationStatus, ProposalStatus};

    #[test]
    #[available_gas(10000000)]
    fn cancelled() {
        let mut proposal: Proposal = Default::default();
        proposal.finalization_status = FinalizationStatus::Cancelled(());
        let quorum = 1;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @proposal, quorum, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Cancelled(()), 'failed cancelled');
    }

    #[test]
    #[available_gas(10000000)]
    fn executed() {
        let mut proposal: Proposal = Default::default();
        proposal.finalization_status = FinalizationStatus::Executed(());
        let quorum = 1;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @proposal, quorum, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Executed(()), 'failed executed');
    }

    #[test]
    #[available_gas(10000000)]
    fn voting_delay() {
        let mut proposal: Proposal = Default::default();
        proposal.start_timestamp = 42424242;
        let quorum = 1;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @proposal, quorum, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingDelay(()), 'failed voting_delay');
    }

    #[test]
    #[available_gas(10000000)]
    fn voting_period() {
        let mut proposal: Proposal = Default::default();
        proposal.min_end_timestamp = 42424242;
        proposal.max_end_timestamp = proposal.min_end_timestamp + 1;
        let quorum = 1;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @proposal, quorum, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingPeriod(()), 'failed min_end_timestamp');
    }

    #[test]
    #[available_gas(10000000)]
    fn early_end() {
        let mut proposal: Proposal = Default::default();
        proposal.max_end_timestamp = 10;
        let quorum = 1;
        let votes_for = 1;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @proposal, quorum, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingPeriodAccepted(()), 'failed early end');
    }

    #[test]
    #[available_gas(10000000)]
    fn balanced() {
        let mut proposal: Proposal = Default::default();
        let quorum = 1;
        let votes_for = 42;
        let votes_against = 42;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @proposal, quorum, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Rejected(()), 'failed balanced');
    }

    #[test]
    #[available_gas(10000000)]
    fn accepted() {
        let mut proposal: Proposal = Default::default();
        let quorum = 10;
        let votes_for = 10;
        let votes_against = 9;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @proposal, quorum, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Accepted(()), 'failed accepted');
    }

    #[test]
    #[available_gas(10000000)]
    fn quorum_not_reached() {
        let mut proposal: Proposal = Default::default();
        let quorum = 10;
        let votes_for = 5;
        let votes_against = 4;
        let votes_abstain = 3;
        let result = get_proposal_status(
            @proposal, quorum, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Rejected(()), 'failed accepted');
    }

    #[test]
    #[available_gas(10000000)]
    fn accepted_with_abstains() {
        let mut proposal: Proposal = Default::default();
        let quorum = 10;
        let votes_for = 2;
        let votes_against = 1;
        let votes_abstain = 10;
        let result = get_proposal_status(
            @proposal, quorum, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Accepted(()), 'failed accepted abstains');
    }

    #[test]
    #[available_gas(10000000)]
    fn rejected_only_againsts() {
        let mut proposal: Proposal = Default::default();
        let quorum = 1;
        let votes_for = 0;
        let votes_against = 2;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @proposal, quorum, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Rejected(()), 'failed rejected');
    }
}
