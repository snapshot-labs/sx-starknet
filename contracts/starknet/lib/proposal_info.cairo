// SPDX-License-Identifier: MIT

from starkware.cairo.common.uint256 import Uint256

from contracts.starknet.lib.proposal import Proposal

struct ProposalInfo {
    proposal: Proposal,
    power_for: Uint256,
    power_against: Uint256,
    power_abstain: Uint256,
}
