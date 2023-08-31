use serde::Serde;
use traits::Default;

#[derive(Copy, Drop, Default, Serde, PartialEq)]
enum ProposalStatus {
    #[default]
    VotingDelay: (),
    VotingPeriod: (),
    VotingPeriodAccepted: (),
    Accepted: (),
    Executed: (),
    Rejected: (),
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

