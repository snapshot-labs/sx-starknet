#[starknet::contract]
mod VanillaExecutionStrategy {
    use sx::interfaces::{IExecutionStrategy, IQuorum};
    use sx::types::{Proposal, ProposalStatus};
    use sx::execution_strategies::simple_quorum::SimpleQuorumExecutionStrategy;


    #[storage]
    struct Storage {
        _num_executed: felt252
    }

    #[external(v0)]
    impl QuorumImpl of IQuorum<ContractState> {
        fn quorum(self: @ContractState) -> u256 {
            let mut state: SimpleQuorumExecutionStrategy::ContractState =
                SimpleQuorumExecutionStrategy::unsafe_new_contract_state();

            SimpleQuorumExecutionStrategy::quorum(@state)
        }
    }

    #[external(v0)]
    impl VanillaExecutionStrategy of IExecutionStrategy<ContractState> {
        fn execute(
            ref self: ContractState,
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
            payload: Array<felt252>
        ) {
            // TODO: this is probably wrong. 
            let mut state: SimpleQuorumExecutionStrategy::ContractState =
                SimpleQuorumExecutionStrategy::unsafe_new_contract_state();

            let proposal_status = SimpleQuorumExecutionStrategy::get_proposal_status(
                @state, @proposal, votes_for, votes_against, votes_abstain
            );
            assert(
                (proposal_status == ProposalStatus::Accepted(()))
                    | (proposal_status == ProposalStatus::VotingPeriodAccepted(())),
                'Invalid Proposal Status'
            );
            self._num_executed.write(self._num_executed.read() + 1);
        }

        fn get_strategy_type(self: @ContractState) -> felt252 {
            'SimpleQuorumVanilla'
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, quorum: u256) {
        // TODO: temporary until components are released
        let mut state = SimpleQuorumExecutionStrategy::unsafe_new_contract_state();
        SimpleQuorumExecutionStrategy::initializer(ref state, quorum);
    }

    #[view]
    fn num_executed(self: @ContractState) -> felt252 {
        self._num_executed.read()
    }
}
