#[starknet::contract]
mod SimpleQuorum {
    use starknet::{ContractAddress, info};
    use sx::interfaces::IQuorum;
    use sx::types::{Proposal, FinalizationStatus, ProposalStatus};

    #[storage]
    struct Storage {
        _quorum: u256
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(ref self: ContractState, quorum: u256) {
            self._quorum.write(quorum);
        }

        fn quorum(self: @ContractState) -> u256 {
            self._quorum.read()
        }

        /// Returns the status of a proposal.
        /// To be accepted, a proposal must be supported by a majority of votes, have reached the quorum,
        /// and have the current timestamp be greater or equal to `max_end_timestamp`.
        /// If the proposal is has a majority of votes and have reached the quorum,
        /// then it can be early accepted (it will return `VotingPeriodAccepted`) provided the current timestamp is
        /// between `min_end_timestamp` and `max_end_timestamp`.
        /// Spaces that don't want to deal with early accepting proposals should set `min_voting_duration` and `max_voting_duration`
        /// to the same value.
        fn get_proposal_status(
            self: @ContractState,
            proposal: @Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
        ) -> ProposalStatus {
            let quorum_reached = votes_for + votes_abstain >= self._quorum.read();
            let supported = votes_for > votes_against;
            let accepted = quorum_reached && supported;

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
    }

    #[external(v0)]
    impl Quorum of IQuorum<ContractState> {
        fn quorum(self: @ContractState) -> u256 {
            self._quorum.read()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::SimpleQuorum;
    use sx::types::{Proposal, proposal::ProposalDefault, FinalizationStatus, ProposalStatus};

    #[test]
    #[available_gas(10000000)]
    fn cancelled() {
        let mut state = SimpleQuorum::unsafe_new_contract_state();

        let mut proposal: Proposal = Default::default();
        proposal.finalization_status = FinalizationStatus::Cancelled(());
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = SimpleQuorum::InternalImpl::get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Cancelled(()), 'failed cancelled');
    }

    #[test]
    #[available_gas(10000000)]
    fn executed() {
        let mut state = SimpleQuorum::unsafe_new_contract_state();

        let mut proposal: Proposal = Default::default();
        proposal.finalization_status = FinalizationStatus::Executed(());
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = SimpleQuorum::InternalImpl::get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Executed(()), 'failed executed');
    }

    #[test]
    #[available_gas(10000000)]
    fn voting_delay() {
        let mut state = SimpleQuorum::unsafe_new_contract_state();

        let mut proposal: Proposal = Default::default();
        proposal.start_timestamp = 42424242;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = SimpleQuorum::InternalImpl::get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingDelay(()), 'failed voting_delay');
    }

    #[test]
    #[available_gas(10000000)]
    fn voting_period() {
        let mut state = SimpleQuorum::unsafe_new_contract_state();

        let mut proposal: Proposal = Default::default();
        proposal.min_end_timestamp = 42424242;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = SimpleQuorum::InternalImpl::get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingPeriod(()), 'failed min_end_timestamp');
    }

    #[test]
    #[available_gas(10000000)]
    fn shortcut_accepted() {
        let mut state = SimpleQuorum::unsafe_new_contract_state();
        let quorum = 2;
        SimpleQuorum::InternalImpl::initializer(ref state, quorum);

        let mut proposal: Proposal = Default::default();
        proposal.max_end_timestamp = 10;
        let votes_for = quorum;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = SimpleQuorum::InternalImpl::get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingPeriodAccepted(()), 'failed shortcut_accepted');
    }

    #[test]
    #[available_gas(10000000)]
    fn shortcut_only_abstains() {
        let mut state = SimpleQuorum::unsafe_new_contract_state();
        let quorum = 2;
        SimpleQuorum::InternalImpl::initializer(ref state, quorum);

        let mut proposal: Proposal = Default::default();
        proposal.max_end_timestamp = 10;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = quorum;
        let result = SimpleQuorum::InternalImpl::get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingPeriod(()), 'failed shortcut_only_abstains');
    }

    #[test]
    #[available_gas(10000000)]
    fn shortcut_only_againsts() {
        let mut state = SimpleQuorum::unsafe_new_contract_state();
        let quorum = 2;
        SimpleQuorum::InternalImpl::initializer(ref state, quorum);

        let mut proposal: Proposal = Default::default();
        proposal.max_end_timestamp = 10;
        let votes_for = 0;
        let votes_against = quorum;
        let votes_abstain = 0;
        let result = SimpleQuorum::InternalImpl::get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingPeriod(()), 'failed shortcut_only_againsts');
    }

    #[test]
    #[available_gas(10000000)]
    fn shortcut_balanced() {
        let mut state = SimpleQuorum::unsafe_new_contract_state();
        let quorum = 2;
        SimpleQuorum::InternalImpl::initializer(ref state, quorum);

        let mut proposal: Proposal = Default::default();
        proposal.max_end_timestamp = 10;
        let votes_for = quorum;
        let votes_against = quorum;
        let votes_abstain = 0;
        let result = SimpleQuorum::InternalImpl::get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::VotingPeriod(()), 'failed shortcut_balanced');
    }

    #[test]
    #[available_gas(10000000)]
    fn balanced() {
        let mut state = SimpleQuorum::unsafe_new_contract_state();
        let quorum = 2;
        SimpleQuorum::InternalImpl::initializer(ref state, quorum);

        let mut proposal: Proposal = Default::default();
        let votes_for = quorum;
        let votes_against = quorum;
        let votes_abstain = 0;
        let result = SimpleQuorum::InternalImpl::get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Rejected(()), 'failed balanced');
    }

    #[test]
    #[available_gas(10000000)]
    fn accepted() {
        let mut state = SimpleQuorum::unsafe_new_contract_state();
        let quorum = 2;
        SimpleQuorum::InternalImpl::initializer(ref state, quorum);

        let mut proposal: Proposal = Default::default();
        let votes_for = quorum;
        let votes_against = quorum - 1;
        let votes_abstain = 0;
        let result = SimpleQuorum::InternalImpl::get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Accepted(()), 'failed accepted');
    }

    #[test]
    #[available_gas(10000000)]
    fn accepted_with_abstains() {
        let mut state = SimpleQuorum::unsafe_new_contract_state();
        let quorum = 5;
        SimpleQuorum::InternalImpl::initializer(ref state, quorum);

        let mut proposal: Proposal = Default::default();
        let votes_for = 2;
        let votes_against = 1;
        let votes_abstain = 10;
        let result = SimpleQuorum::InternalImpl::get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Accepted(()), 'failed accepted abstains');
    }

    #[test]
    #[available_gas(10000000)]
    fn rejected_only_againsts() {
        let mut state = SimpleQuorum::unsafe_new_contract_state();
        let quorum = 0;
        SimpleQuorum::InternalImpl::initializer(ref state, quorum);

        let mut proposal: Proposal = Default::default();
        let votes_for = 0;
        let votes_against = 1;
        let votes_abstain = 0;
        let result = SimpleQuorum::InternalImpl::get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Rejected(()), 'failed rejected');
    }

    #[test]
    #[available_gas(10000000)]
    fn quorum_not_reached() {
        let mut state = SimpleQuorum::unsafe_new_contract_state();
        let quorum = 3;
        SimpleQuorum::InternalImpl::initializer(ref state, quorum);

        let mut proposal: Proposal = Default::default();
        let votes_for = 2;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = SimpleQuorum::InternalImpl::get_proposal_status(
            @state, @proposal, votes_for, votes_against, votes_abstain
        );
        assert(result == ProposalStatus::Rejected(()), 'failed quorum_not_reached');
    }
}
