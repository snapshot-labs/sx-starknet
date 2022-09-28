from contracts.starknet.lib.proposal import Proposal

struct ProposalInfo {
    proposal: Proposal,
    power_for: felt,
    power_against: felt,
    power_abstain: felt,
}
