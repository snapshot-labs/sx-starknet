#[contract]
mod VanillaExecutionStrategy {
    use sx::interfaces::IExecutionStrategy;
    use sx::utils::types::{Proposal, ProposalStatus};
    use sx::execution_strategies::simple_quorum::SimpleQuorumExecutionStrategy;

    struct Storage {
        _num_executed: felt252
    }

    impl VanillaExecutionStrategy of IExecutionStrategy {
        fn execute(
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
            payload: Array<felt252>
        ) {
            let proposal_status = SimpleQuorumExecutionStrategy::get_proposal_status(
                @proposal, votes_for, votes_against, votes_abstain
            );
            assert(
                (proposal_status == ProposalStatus::Accepted(
                    ()
                )) | (proposal_status == ProposalStatus::VotingPeriodAccepted(())),
                'Invalid Proposal Status'
            );
            _num_executed::write(_num_executed::read() + 1);
        }
    }

    #[constructor]
    fn constructor(quorum: u256) {
        SimpleQuorumExecutionStrategy::initializer(quorum);
    }

    #[external]
    fn execute(
        proposal: Proposal,
        votes_for: u256,
        votes_against: u256,
        votes_abstain: u256,
        payload: Array<felt252>
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
