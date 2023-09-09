/// Enum to represent the different statuses of a proposal.
#[derive(Copy, Drop, Default, Serde, PartialEq)]
enum ProposalStatus {
    #[default]
    /// The voting period has not started yet.
    VotingDelay: (),
    /// The vote is ongoing.
    VotingPeriod: (),
    /// The voting period is not completely over but the proposal can already
    /// be accepted (see the `min_voting_duration` field in [`Proposal`]).
    VotingPeriodAccepted: (),
    /// The proposal has been accepted.
    Accepted: (),
    /// The proposal has been executed.
    Executed: (),
    /// The proposal has been rejected.
    Rejected: (),
    /// The proposal has been cancelled.
    Cancelled: ()
}

impl ProposalStatusIntoU8 of Into<ProposalStatus, u8> {
    fn into(self: ProposalStatus) -> u8 {
        match self {
            ProposalStatus::VotingDelay(_) => 0_u8,
            ProposalStatus::VotingPeriod(_) => 1_u8,
            ProposalStatus::VotingPeriodAccepted(_) => 2_u8,
            ProposalStatus::Accepted(_) => 3_u8,
            ProposalStatus::Executed(_) => 4_u8,
            ProposalStatus::Rejected(_) => 5_u8,
            ProposalStatus::Cancelled(_) => 6_u8,
        }
    }
}

