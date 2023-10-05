use starknet::{ContractAddress, storage_access::StorePacking, Store, contract_address_const};
use sx::{
    utils::math::pow,
    types::{ContractAddressDefault, FinalizationStatus, UserAddress, UserAddressTrait},
};

const BITMASK_32: u128 = 0xffffffff;
const BITMASK_64: u128 = 0xffffffffffffffff;
const BITMASK_128: u128 = 0xffffffffffffffffffffffffffffffff;

const BITMASK_SECOND_U32: u128 = 0xffffffff00000000;
const BITMASK_THIRD_U32: u128 = 0xffffffff0000000000000000;
const BITMASK_FOURTH_U32: u128 =
    0xff000000000000000000000000; // Only 0xff because finalization_status is an u8

const TWO_POWER_32: u128 = 0x100000000;
const TWO_POWER_64: u128 = 0x10000000000000000;
const TWO_POWER_96: u128 = 0x1000000000000000000000000;

/// Data stored when a proposal is created.
/// The proposal state at any time consists of this struct along with the corresponding for,
/// against, and abstain vote counts. The proposal status is a function of the proposal state as
/// defined in the execution strategy for the proposal.
#[derive(Clone, Default, Drop, Serde, PartialEq)]
struct Proposal {
    /// The timestamp at which the voting period starts.
    start_timestamp: u32,
    /// The timestamp at which a proposal can be early finalized.
    /// Spaces that do not want this feature should ensure `min_voting_duration`
    /// and `max_voting_duration` are set at the same value.
    min_end_timestamp: u32,
    /// The timestamp at which the voting period ends.
    max_end_timestamp: u32,
    /// The finalization status of the proposal.
    finalization_status: FinalizationStatus,
    /// The hash of the execution payload.
    execution_payload_hash: felt252,
    /// The address of the execution strategy.
    execution_strategy: ContractAddress,
    /// The address of the proposal author.
    author: UserAddress,
    /// Bit array where the index of each each bit corresponds to whether the voting strategy at
    /// that index is active at the time of proposal creation.
    active_voting_strategies: u256
}

/// A packed version of the `Proposal` struct. Used to minimize storage costs.
#[derive(Drop, starknet::Store)]
struct PackedProposal {
    timestamps_and_finalization_status: u128, // In order: start, min, max, finalization_status
    execution_payload_hash: felt252,
    execution_strategy: ContractAddress,
    author: UserAddress,
    active_voting_strategies: u256,
}

impl ProposalStorePacking of StorePacking<Proposal, PackedProposal> {
    fn pack(value: Proposal) -> PackedProposal {
        let timestamps_and_finalization_status: u128 = (value.start_timestamp.into()
            + value.min_end_timestamp.into() * TWO_POWER_32
            + value.max_end_timestamp.into() * TWO_POWER_64
            + value.finalization_status.into() * TWO_POWER_96);
        PackedProposal {
            timestamps_and_finalization_status,
            execution_payload_hash: value.execution_payload_hash,
            execution_strategy: value.execution_strategy,
            author: value.author,
            active_voting_strategies: value.active_voting_strategies,
        }
    }

    fn unpack(value: PackedProposal) -> Proposal {
        let start_timestamp: u32 = (value.timestamps_and_finalization_status & BITMASK_32)
            .try_into()
            .unwrap();
        let min_end_timestamp: u32 = ((value.timestamps_and_finalization_status
            & BITMASK_SECOND_U32)
            / TWO_POWER_32)
            .try_into()
            .unwrap();
        let max_end_timestamp: u32 = ((value.timestamps_and_finalization_status & BITMASK_THIRD_U32)
            / TWO_POWER_64)
            .try_into()
            .unwrap();
        let finalization_status: u8 = ((value.timestamps_and_finalization_status
            & BITMASK_FOURTH_U32)
            / TWO_POWER_96)
            .try_into()
            .unwrap();

        let type_helper: Option<FinalizationStatus> = finalization_status
            .try_into(); // For some reason, type couldn't be inferred...
        let finalization_status: FinalizationStatus = type_helper.unwrap();

        Proposal {
            start_timestamp,
            min_end_timestamp,
            max_end_timestamp,
            finalization_status,
            execution_payload_hash: value.execution_payload_hash,
            execution_strategy: value.execution_strategy,
            author: value.author,
            active_voting_strategies: value.active_voting_strategies,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{Proposal, PackedProposal, ProposalStorePacking};
    use super::FinalizationStatus;
    use starknet::storage_access::StorePacking;
    use starknet::contract_address_const;
    use sx::types::{UserAddress};
    use clone::Clone;

    #[test]
    fn pack_zero() {
        let proposal = Proposal {
            start_timestamp: 0,
            min_end_timestamp: 0,
            max_end_timestamp: 0,
            finalization_status: FinalizationStatus::Pending(()),
            execution_payload_hash: 0,
            author: UserAddress::Starknet(contract_address_const::<0>()),
            execution_strategy: contract_address_const::<0>(),
            active_voting_strategies: 0_u256,
        };

        let packed = ProposalStorePacking::pack(proposal.clone());
        assert(packed.timestamps_and_finalization_status == 0, 'invalid zero packing');
        let result = ProposalStorePacking::unpack(packed);
        assert(result == proposal, 'invalid zero unpacking');
    }


    #[test]
    fn pack_start_timestamp() {
        let proposal = Proposal {
            start_timestamp: 42,
            min_end_timestamp: 0,
            max_end_timestamp: 0,
            finalization_status: FinalizationStatus::Pending(()),
            execution_payload_hash: 0,
            author: UserAddress::Starknet(contract_address_const::<0>()),
            execution_strategy: contract_address_const::<0>(),
            active_voting_strategies: 0_u256,
        };

        let packed = ProposalStorePacking::pack(proposal.clone());
        assert(packed.timestamps_and_finalization_status == 42, 'invalid start packing');
        let result = ProposalStorePacking::unpack(packed);
        assert(result == proposal, 'invalid start unpacking');
    }

    #[test]
    fn pack_min_timestamp() {
        let proposal = Proposal {
            start_timestamp: 0,
            min_end_timestamp: 42,
            max_end_timestamp: 0,
            finalization_status: FinalizationStatus::Pending(()),
            execution_payload_hash: 0,
            author: UserAddress::Starknet(contract_address_const::<0>()),
            execution_strategy: contract_address_const::<0>(),
            active_voting_strategies: 0_u256,
        };

        let packed = ProposalStorePacking::pack(proposal.clone());
        assert(packed.timestamps_and_finalization_status == 0x2a00000000, 'invalid min packing');
        let result = ProposalStorePacking::unpack(packed);
        assert(result == proposal, 'invalid min unpacking');
    }


    #[test]
    fn pack_max_timestamp() {
        let proposal = Proposal {
            start_timestamp: 0,
            min_end_timestamp: 0,
            max_end_timestamp: 42,
            finalization_status: FinalizationStatus::Pending(()),
            execution_payload_hash: 0,
            author: UserAddress::Starknet(contract_address_const::<0>()),
            execution_strategy: contract_address_const::<0>(),
            active_voting_strategies: 0_u256,
        };

        let packed = ProposalStorePacking::pack(proposal.clone());
        assert(
            packed.timestamps_and_finalization_status == 0x2a0000000000000000, 'invalid max packing'
        );
        let result = ProposalStorePacking::unpack(packed);
        assert(result == proposal, 'invalid max unpacking');
    }

    #[test]
    fn pack_finalization_status() {
        let proposal = Proposal {
            start_timestamp: 0,
            min_end_timestamp: 0,
            max_end_timestamp: 0,
            finalization_status: FinalizationStatus::Executed(()),
            execution_payload_hash: 0,
            author: UserAddress::Starknet(contract_address_const::<0>()),
            execution_strategy: contract_address_const::<0>(),
            active_voting_strategies: 0_u256,
        };

        let packed = ProposalStorePacking::pack(proposal.clone());
        assert(
            packed.timestamps_and_finalization_status == 0x01000000000000000000000000,
            'invalid status packing'
        );
        let result = ProposalStorePacking::unpack(packed);
        assert(result == proposal, 'invalid status unpacking');
    }

    #[test]
    fn pack_full() {
        let proposal = Proposal {
            start_timestamp: 0xffffffff,
            min_end_timestamp: 0xffffffff,
            max_end_timestamp: 0xffffffff,
            finalization_status: FinalizationStatus::Cancelled(()),
            execution_payload_hash: 0,
            author: UserAddress::Starknet(contract_address_const::<0>()),
            execution_strategy: contract_address_const::<0>(),
            active_voting_strategies: 0_u256,
        };

        let packed = ProposalStorePacking::pack(proposal.clone());
        assert(
            packed.timestamps_and_finalization_status == 0x02ffffffffffffffffffffffff,
            'invalid full packing'
        );
        let result = ProposalStorePacking::unpack(packed);
        assert(result == proposal, 'invalid full unpacking');
    }
}

