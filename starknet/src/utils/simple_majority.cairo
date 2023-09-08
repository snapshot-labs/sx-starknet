use starknet::info;
use sx::types::{Proposal, FinalizationStatus, ProposalStatus};

/// Returns the status of a proposal, according to a 'Simple Majority' rule.
/// 'Simple Majority' is defined like so: a proposal is accepted if there are more `votes_for` than `votes_against`.
/// So, a proposal will return Accepted if `max_end_timestamp` has been reached, and `votes_for > votes_agasint`.
fn get_proposal_status(
    proposal: @Proposal, votes_for: u256, votes_against: u256, votes_abstain: u256,
) -> ProposalStatus {
    let accepted = votes_for > votes_against;

    let timestamp = info::get_block_timestamp().try_into().unwrap();
    if *proposal.finalization_status == FinalizationStatus::Cancelled(()) {
        ProposalStatus::Cancelled(())
    } else if *proposal.finalization_status == FinalizationStatus::Executed(()) {
        ProposalStatus::Executed(())
    } else if timestamp < *proposal.start_timestamp {
        ProposalStatus::VotingDelay(())
    } else if timestamp < *proposal.max_end_timestamp {
        ProposalStatus::VotingPeriod(())
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
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::Cancelled(()), 'failed cancelled');
    }

    #[test]
    #[available_gas(10000000)]
    fn executed() {
        let mut proposal: Proposal = Default::default();
        proposal.finalization_status = FinalizationStatus::Executed(());
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::Executed(()), 'failed executed');
    }

    #[test]
    #[available_gas(10000000)]
    fn voting_delay() {
        let mut proposal: Proposal = Default::default();
        proposal.start_timestamp = 42424242;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::VotingDelay(()), 'failed voting_delay');
    }

    #[test]
    #[available_gas(10000000)]
    fn voting_period() {
        let mut proposal: Proposal = Default::default();
        proposal.min_end_timestamp = 42424242;
        proposal.max_end_timestamp = proposal.min_end_timestamp + 1;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::VotingPeriod(()), 'failed min_end_timestamp');
    }

    #[test]
    #[available_gas(10000000)]
    fn early_end_does_not_work() {
        let mut proposal: Proposal = Default::default();
        proposal.max_end_timestamp = 10;
        let votes_for = 1;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::VotingPeriod(()), 'failed shortcut_accepted');
    }

    #[test]
    #[available_gas(10000000)]
    fn balanced() {
        let mut proposal: Proposal = Default::default();
        let votes_for = 42;
        let votes_against = 42;
        let votes_abstain = 0;
        let result = get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::Rejected(()), 'failed balanced');
    }

    #[test]
    #[available_gas(10000000)]
    fn accepted() {
        let mut proposal: Proposal = Default::default();
        let votes_for = 10;
        let votes_against = 9;
        let votes_abstain = 0;
        let result = get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::Accepted(()), 'failed accepted');
    }

    #[test]
    #[available_gas(10000000)]
    fn accepted_with_abstains() {
        let mut proposal: Proposal = Default::default();
        let votes_for = 2;
        let votes_against = 1;
        let votes_abstain = 10;
        let result = get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::Accepted(()), 'failed accepted abstains');
    }

    #[test]
    #[available_gas(10000000)]
    fn rejected_only_againsts() {
        let mut proposal: Proposal = Default::default();
        let votes_for = 0;
        let votes_against = 1;
        let votes_abstain = 0;
        let result = get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::Rejected(()), 'failed rejected');
    }
}
