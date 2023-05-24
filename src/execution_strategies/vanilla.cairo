#[contract]
mod VanillaExecutionStrategy {
    use sx::utils::types::Proposal;

    struct Storage {
        _num_executed: felt252
    }

    #[external]
    fn execute(proposal: Proposal, votes_for: u256, votes_against: u256, votes_abstain: u256) {
        _num_executed::write(_num_executed::read() + 1);
    }
}
