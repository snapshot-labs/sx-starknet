// SPDX-License-Identifier: MIT

from starkware.cairo.common.uint256 import Uint256

struct Proposal {
    quorum: Uint256,
    // timestamps contains the following packed into a single felt (each one is 32 bit):
    // snapshot_timestamp, start_timestamp, min_end_timestamp, max_end_timestamp
    timestamps: felt,
    execution_strategy: felt,
    execution_hash: felt,
}
