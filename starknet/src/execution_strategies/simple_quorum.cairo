use core::traits::TryInto;
#[starknet::contract]
mod SimpleQuorumExecutionStrategy {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::info;
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
    fn quorum(self: @ContractState) -> u256 {
        self._quorum.read()
    }

    #[internal]
    fn get_proposal_status(
        self: @ContractState,
        proposal: @Proposal,
        votes_for: u256,
        votes_against: u256,
        votes_abstain: u256,
    ) -> ProposalStatus {
        let accepted = _quorum_reached(self._quorum.read(), votes_for, votes_against, votes_abstain)
            & _supported(votes_for, votes_against);

        let timestamp = info::get_block_timestamp().try_into().unwrap();
        if *proposal.finalization_status == FinalizationStatus::Cancelled(()) {
            ProposalStatus::Cancelled(())
        } else if *proposal.finalization_status == FinalizationStatus::Executed(()) {
            ProposalStatus::Executed(())
        } else if timestamp < *proposal.start_timestamp {
            ProposalStatus::VotingDelay(())
        } else if timestamp < *proposal.min_end_timestamp {
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

#[cfg(test)]
mod tests {
    use super::SimpleQuorumExecutionStrategy;
    use super::SimpleQuorumExecutionStrategy::{get_proposal_status, initializer};
    use sx::types::{Proposal, proposal::ProposalDefault, FinalizationStatus, ProposalStatus};

    #[test]
    #[available_gas(10000000)]
    fn cancelled() {
        let mut state = SimpleQuorumExecutionStrategy::unsafe_new_contract_state();

        let mut proposal = ProposalDefault::default();
        proposal.finalization_status = FinalizationStatus::Cancelled(());
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Cancelled(()), 'failed cancelled');
    }

    #[test]
    #[available_gas(10000000)]
    fn executed() {
        let mut state = SimpleQuorumExecutionStrategy::unsafe_new_contract_state();

        let mut proposal = ProposalDefault::default();
        proposal.finalization_status = FinalizationStatus::Executed(());
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Executed(()), 'failed executed');
    }

    #[test]
    #[available_gas(10000000)]
    fn voting_delay() {
        let mut state = SimpleQuorumExecutionStrategy::unsafe_new_contract_state();

        let mut proposal = ProposalDefault::default();
        proposal.start_timestamp = 42424242;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingDelay(()), 'failed voting_delay');
    }

    #[test]
    #[available_gas(10000000)]
    fn voting_period() {
        let mut state = SimpleQuorumExecutionStrategy::unsafe_new_contract_state();

        let mut proposal = ProposalDefault::default();
        proposal.min_end_timestamp = 42424242;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingPeriod(()), 'failed min_end_timestamp');
    }

    #[test]
    #[available_gas(10000000)]
    fn shortcut_accepted() {
        let mut state = SimpleQuorumExecutionStrategy::unsafe_new_contract_state();
        let quorum = 2;
        initializer(ref state, quorum);

        let mut proposal = ProposalDefault::default();
        proposal.max_end_timestamp = 10;
        let votes_for = quorum;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingPeriodAccepted(()), 'failed shortcut_accepted');
    }

    #[test]
    #[available_gas(10000000)]
    fn shortcut_only_abstains() {
        let mut state = SimpleQuorumExecutionStrategy::unsafe_new_contract_state();
        let quorum = 2;
        initializer(ref state, quorum);

        let mut proposal = ProposalDefault::default();
        proposal.max_end_timestamp = 10;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = quorum;
        let result = get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingPeriod(()), 'failed shortcut_only_abstains');
    }

    #[test]
    #[available_gas(10000000)]
    fn shortcut_only_againsts() {
        let mut state = SimpleQuorumExecutionStrategy::unsafe_new_contract_state();
        let quorum = 2;
        initializer(ref state, quorum);

        let mut proposal = ProposalDefault::default();
        proposal.max_end_timestamp = 10;
        let votes_for = 0;
        let votes_against = quorum;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingPeriod(()), 'failed shortcut_only_againsts');
    }

    #[test]
    #[available_gas(10000000)]
    fn shortcut_balanced() {
        let mut state = SimpleQuorumExecutionStrategy::unsafe_new_contract_state();
        let quorum = 2;
        initializer(ref state, quorum);

        let mut proposal = ProposalDefault::default();
        proposal.max_end_timestamp = 10;
        let votes_for = quorum;
        let votes_against = quorum;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingPeriod(()), 'failed shortcut_balanced');
    }

    #[test]
    #[available_gas(10000000)]
    fn balanced() {
        let mut state = SimpleQuorumExecutionStrategy::unsafe_new_contract_state();
        let quorum = 2;
        initializer(ref state, quorum);

        let mut proposal = ProposalDefault::default();
        let votes_for = quorum;
        let votes_against = quorum;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Rejected(()), 'failed balanced');
    }

    #[test]
    #[available_gas(10000000)]
    fn accepted() {
        let mut state = SimpleQuorumExecutionStrategy::unsafe_new_contract_state();
        let quorum = 2;
        initializer(ref state, quorum);

        let mut proposal = ProposalDefault::default();
        let votes_for = quorum;
        let votes_against = quorum - 1;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Accepted(()), 'failed accepted');
    }

    #[test]
    #[available_gas(10000000)]
    fn accepted_with_abstains() {
        let mut state = SimpleQuorumExecutionStrategy::unsafe_new_contract_state();
        let quorum = 5;
        initializer(ref state, quorum);

        let mut proposal = ProposalDefault::default();
        let votes_for = 2;
        let votes_against = 1;
        let votes_abstain = 10;
        let result = get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Accepted(()), 'failed accepted abstains');
    }

    #[test]
    #[available_gas(10000000)]
    fn rejected_only_againsts() {
        let mut state = SimpleQuorumExecutionStrategy::unsafe_new_contract_state();
        let quorum = 0;
        initializer(ref state, quorum);

        let mut proposal = ProposalDefault::default();
        let votes_for = 0;
        let votes_against = 1;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Rejected(()), 'failed rejected');
    }

    #[test]
    #[available_gas(10000000)]
    fn quorum_not_reached() {
        let mut state = SimpleQuorumExecutionStrategy::unsafe_new_contract_state();
        let quorum = 3;
        initializer(ref state, quorum);

        let mut proposal = ProposalDefault::default();
        let votes_for = 2;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Rejected(()), 'failed quorum_not_reached');
    }
}
