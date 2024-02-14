#[starknet::contract]
mod VanillaExecutionStrategy {
    use sx::interfaces::{IExecutionStrategy, IQuorum};
    use sx::types::{Proposal, ProposalStatus};
    use sx::utils::SimpleQuorum;


    #[storage]
    struct Storage {
        _num_executed: felt252
    }

    #[external(v0)]
    impl QuorumImpl of IQuorum<ContractState> {
        fn quorum(self: @ContractState) -> u256 {
            let mut state: SimpleQuorum::ContractState = SimpleQuorum::unsafe_new_contract_state();
            SimpleQuorum::InternalImpl::quorum(@state)
        }
    }

    /// The vanilla execution strategy is a dummy execution strategy that simply increments a `_num_executed` variable for every
    /// newly executed proposal. It uses the `SimpleQuorum` method to determine whether a proposal is accepted or not.
    #[external(v0)]
    impl VanillaExecutionStrategy of IExecutionStrategy<ContractState> {
        fn execute(
            ref self: ContractState,
            proposal_id: u256,
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
            payload: Array<felt252>
        ) {
            let proposal_status = self
                .get_proposal_status(proposal, votes_for, votes_against, votes_abstain,);
            assert(
                (proposal_status == ProposalStatus::Accepted(()))
                    | (proposal_status == ProposalStatus::VotingPeriodAccepted(())),
                'Invalid Proposal Status'
            );
            self._num_executed.write(self._num_executed.read() + 1);
        }

        fn get_proposal_status(
            self: @ContractState,
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
        ) -> ProposalStatus {
            let mut state: SimpleQuorum::ContractState = SimpleQuorum::unsafe_new_contract_state();

            SimpleQuorum::InternalImpl::get_proposal_status(
                @state, @proposal, votes_for, votes_against, votes_abstain,
            )
        }

        fn get_strategy_type(self: @ContractState) -> felt252 {
            'SimpleQuorumVanilla'
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, quorum: u256) {
        // Migration to components planned ; disregard the `unsafe` keyword,
        // it is actually safe.
        let mut state = SimpleQuorum::unsafe_new_contract_state();
        SimpleQuorum::InternalImpl::initializer(ref state, quorum);
    }

    #[external(v0)]
    #[generate_trait]
    impl NumExecutedImpl of NumExecutedTrait {
        fn num_executed(self: @ContractState) -> felt252 {
            self._num_executed.read()
        }
    }
}
