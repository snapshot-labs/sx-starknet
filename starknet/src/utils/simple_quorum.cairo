#[starknet::component]
mod SimpleQuorumComponent {
    use starknet::{ContractAddress, info};
    use sx::interfaces::IQuorum;
    use sx::types::{Proposal, FinalizationStatus, ProposalStatus};

    #[storage]
    struct Storage {
        Simplequorum_quorum: u256
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, quorum: u256) {
            self.Simplequorum_quorum.write(quorum);
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
            self: @ComponentState<TContractState>,
            proposal: @Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
        ) -> ProposalStatus {
            let quorum_reached = votes_for + votes_abstain >= self.Simplequorum_quorum.read();
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

    #[embeddable_as(SimpleQuorumImpl)]
    impl SimpleQuorum<
        TContractState, +HasComponent<TContractState>
    > of IQuorum<ComponentState<TContractState>> {
        fn quorum(self: @ComponentState<TContractState>) -> u256 {
            self.Simplequorum_quorum.read()
        }
    }
}


#[cfg(test)]
mod tests {
    use super::SimpleQuorumComponent;
    use super::SimpleQuorumComponent::InternalTrait;
    use sx::types::{Proposal, proposal::ProposalDefault, FinalizationStatus, ProposalStatus};

    // You need an actual contract to test a component.
    #[starknet::contract]
    mod MockContract {
        use super::SimpleQuorumComponent;
        use sx::types::{Proposal, ProposalStatus};

        component!(path: SimpleQuorumComponent, storage: simple_quorum, event: SimpleQuorumEvent);

        #[abi(embed_v0)]
        impl SimpleQuorumImpl =
            SimpleQuorumComponent::SimpleQuorumImpl<ContractState>;
        impl SimpleQuorumInternalImpl = SimpleQuorumComponent::InternalImpl<ContractState>;

        #[storage]
        struct Storage {
            #[substorage(v0)]
            simple_quorum: SimpleQuorumComponent::Storage,
        }

        #[event]
        #[derive(Drop, starknet::Event)]
        pub enum Event {
            #[flat]
            SimpleQuorumEvent: SimpleQuorumComponent::Event,
        }

        #[constructor]
        fn constructor(ref self: ContractState, quorum: u256) {
            self.simple_quorum.initializer(quorum);
        }
    }

    type ComponentState = SimpleQuorumComponent::ComponentState<MockContract::ContractState>;

    fn COMPONENT_STATE() -> ComponentState {
        SimpleQuorumComponent::component_state_for_testing()
    }

    #[test]
    #[available_gas(10000000)]
    fn cancelled() {
        let mut state = COMPONENT_STATE();

        let mut proposal: Proposal = Default::default();
        proposal.finalization_status = FinalizationStatus::Cancelled(());
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = state.get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::Cancelled(()), 'failed cancelled');
    }

    #[test]
    #[available_gas(10000000)]
    fn executed() {
        let mut state = COMPONENT_STATE();

        let mut proposal: Proposal = Default::default();
        proposal.finalization_status = FinalizationStatus::Executed(());
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = state.get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::Executed(()), 'failed executed');
    }

    #[test]
    #[available_gas(10000000)]
    fn voting_delay() {
        let mut state = COMPONENT_STATE();

        let mut proposal: Proposal = Default::default();
        proposal.start_timestamp = 42424242;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = state.get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::VotingDelay(()), 'failed voting_delay');
    }

    #[test]
    #[available_gas(10000000)]
    fn voting_period() {
        let mut state = COMPONENT_STATE();

        let mut proposal: Proposal = Default::default();
        proposal.min_end_timestamp = 42424242;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = state.get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::VotingPeriod(()), 'failed min_end_timestamp');
    }

    #[test]
    #[available_gas(10000000)]
    fn shortcut_accepted() {
        let mut state = COMPONENT_STATE();
        let quorum = 2;
        state.initializer(quorum);

        let mut proposal: Proposal = Default::default();
        proposal.max_end_timestamp = 10;
        let votes_for = quorum;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = state.get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::VotingPeriodAccepted(()), 'failed shortcut_accepted');
    }

    #[test]
    #[available_gas(10000000)]
    fn shortcut_only_abstains() {
        let mut state = COMPONENT_STATE();
        let quorum = 2;
        state.initializer(quorum);

        let mut proposal: Proposal = Default::default();
        proposal.max_end_timestamp = 10;
        let votes_for = 0;
        let votes_against = 0;
        let votes_abstain = quorum;
        let result = state.get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::VotingPeriod(()), 'failed shortcut_only_abstains');
    }

    #[test]
    #[available_gas(10000000)]
    fn shortcut_only_againsts() {
        let mut state = COMPONENT_STATE();
        let quorum = 2;
        state.initializer(quorum);

        let mut proposal: Proposal = Default::default();
        proposal.max_end_timestamp = 10;
        let votes_for = 0;
        let votes_against = quorum;
        let votes_abstain = 0;
        let result = state.get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::VotingPeriod(()), 'failed shortcut_only_againsts');
    }

    #[test]
    #[available_gas(10000000)]
    fn shortcut_balanced() {
        let mut state = COMPONENT_STATE();
        let quorum = 2;
        state.initializer(quorum);

        let mut proposal: Proposal = Default::default();
        proposal.max_end_timestamp = 10;
        let votes_for = quorum;
        let votes_against = quorum;
        let votes_abstain = 0;
        let result = state.get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::VotingPeriod(()), 'failed shortcut_balanced');
    }

    #[test]
    #[available_gas(10000000)]
    fn balanced() {
        let mut state = COMPONENT_STATE();
        let quorum = 2;
        state.initializer(quorum);

        let mut proposal: Proposal = Default::default();
        let votes_for = quorum;
        let votes_against = quorum;
        let votes_abstain = 0;
        let result = state.get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::Rejected(()), 'failed balanced');
    }

    #[test]
    #[available_gas(10000000)]
    fn accepted() {
        let mut state = COMPONENT_STATE();
        let quorum = 2;
        state.initializer(quorum);

        let mut proposal: Proposal = Default::default();
        let votes_for = quorum;
        let votes_against = quorum - 1;
        let votes_abstain = 0;
        let result = state.get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::Accepted(()), 'failed accepted');
    }

    #[test]
    #[available_gas(10000000)]
    fn accepted_with_abstains() {
        let mut state = COMPONENT_STATE();
        let quorum = 5;
        state.initializer(quorum);

        let mut proposal: Proposal = Default::default();
        let votes_for = 2;
        let votes_against = 1;
        let votes_abstain = 10;
        let result = state.get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::Accepted(()), 'failed accepted abstains');
    }

    #[test]
    #[available_gas(10000000)]
    fn rejected_only_againsts() {
        let mut state = COMPONENT_STATE();
        let quorum = 0;
        state.initializer(quorum);

        let mut proposal: Proposal = Default::default();
        let votes_for = 0;
        let votes_against = 1;
        let votes_abstain = 0;
        let result = state.get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::Rejected(()), 'failed rejected');
    }

    #[test]
    #[available_gas(10000000)]
    fn quorum_not_reached() {
        let mut state = COMPONENT_STATE();
        let quorum = 3;
        state.initializer(quorum);

        let mut proposal: Proposal = Default::default();
        let votes_for = 2;
        let votes_against = 0;
        let votes_abstain = 0;
        let result = state.get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::Rejected(()), 'failed quorum_not_reached');
    }

    #[test]
    #[available_gas(10000000)]
    fn quorum_not_reached_with_against_votes() {
        let mut state = COMPONENT_STATE();
        let quorum = 6;
        state.initializer(quorum);

        let mut proposal: Proposal = Default::default();
        // quorum only takes into account for and abstain votes
        let votes_for = 3;
        let votes_against = 2;
        let votes_abstain = 1;
        let result = state.get_proposal_status(@proposal, votes_for, votes_against, votes_abstain);
        assert(result == ProposalStatus::Rejected(()), 'failed quorum_not_reached');
    }
}
