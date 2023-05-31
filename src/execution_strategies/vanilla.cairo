#[contract]
mod VanillaExecutionStrategy {
    use sx::interfaces::IExecutionStrategy;
    use sx::utils::types::Proposal;

    struct Storage {
        _num_executed: felt252
    }

    impl VanillaExecutionStrategy of IExecutionStrategy {
        fn execute(
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
            payload: Array<u8>
        ) {
            _num_executed::write(_num_executed::read() + 1);
        }
    }

    #[external]
    fn execute(
        proposal: Proposal,
        votes_for: u256,
        votes_against: u256,
        votes_abstain: u256,
        payload: Array<u8>
    ) {
        VanillaExecutionStrategy::execute(
            proposal, votes_for, votes_against, votes_abstain, payload
        );
    }

    #[view]
    fn num_executed() -> felt252 {
        _num_executed::read()
    }
}
