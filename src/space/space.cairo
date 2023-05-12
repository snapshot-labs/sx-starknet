use core::traits::AddEq;
use starknet::{
    ContractAddress, StorageAccess, StorageBaseAddress, SyscallResult, storage_write_syscall,
    storage_read_syscall, storage_address_from_base_and_offset,
    contract_address::Felt252TryIntoContractAddress
};
use array::ArrayTrait;
use serde::Serde;
use traits::Into;
use traits::TryInto;
use option::OptionTrait;

#[derive(Drop, Serde)]
struct Strategy {
    address: ContractAddress,
    params: Array<u8>,
}

#[derive(Drop, Serde)]
struct Proposal {
    snapshot_timestamp: u32,
    start_timestamp: u32,
    min_end_timestamp: u32,
    max_end_timestamp: u32,
    execution_payload_hash: u256,
    execution_strategy: ContractAddress,
    author: ContractAddress,
    finalization_status: u8,
    active_voting_strategies: u256
}

impl StorageAccessU8Array of StorageAccess<Array<u8>> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Array<u8>> {
        let length = storage_read_syscall(
            address_domain, storage_address_from_base_and_offset(base, 0_u8)
        )?
            .try_into()
            .unwrap();
        let mut a = ArrayTrait::<u8>::new();
        let mut i = 0_usize;
        loop {
            if i >= length {
                break ();
            }
            a
                .append(
                    storage_read_syscall(
                        address_domain,
                        storage_address_from_base_and_offset(base, i.try_into().unwrap())
                    )?
                        .try_into()
                        .unwrap()
                );
            i += 1;
        };
        Result::Ok(a)
    }

    fn write(address_domain: u32, base: StorageBaseAddress, value: Array<u8>) -> SyscallResult<()> {
        // Write length at offset 0
        storage_write_syscall(
            address_domain, storage_address_from_base_and_offset(base, 0_u8), value.len().into()
        )?;
        let mut i = 1_usize;
        loop {
            if i >= value.len() {
                break ();
            }
            storage_write_syscall(
                address_domain,
                storage_address_from_base_and_offset(base, i.try_into().unwrap()),
                (*value.at(i)).into()
            )?;
        };
        Result::Ok(())
    }
}

// TODO: Implement proper storage for params bytes array
impl StorageAccessStrategy of StorageAccess<Strategy> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Strategy> {
        // Dummy implementation
        let mut a = ArrayTrait::<u8>::new();
        a
            .append(
                storage_read_syscall(
                    address_domain, storage_address_from_base_and_offset(base, 1_u8)
                )?
                    .try_into()
                    .unwrap()
            );
        Result::Ok(
            Strategy {
                address: storage_read_syscall(
                    address_domain, storage_address_from_base_and_offset(base, 0_u8)
                )?
                    .try_into()
                    .unwrap(),
                params: a
            }
        )
    }
    #[inline(always)]
    fn write(address_domain: u32, base: StorageBaseAddress, value: Strategy) -> SyscallResult<()> {
        storage_write_syscall(
            address_domain, storage_address_from_base_and_offset(base, 0_u8), value.address.into()
        )?;

        storage_write_syscall(
            address_domain,
            storage_address_from_base_and_offset(base, 1_u8),
            (*value.params.at(0)).into()
        )
    }
}

#[abi]
trait ISpace {
    fn max_voting_duration() -> u256;
    fn min_voting_duration() -> u256;
    fn next_proposal_id() -> u256;
    fn voting_delay() -> u256;
    fn authenticators(account: ContractAddress) -> bool;
    fn voting_strategies(index: u8) -> Strategy;
    fn active_voting_strategies() -> u256;
    fn next_voting_strategy_index() -> u8;
    fn proposal_validation_strategy() -> Strategy;
    fn vote_power(proposal_id: u256, choice: u8) -> u256;
    fn vote_registry(proposal_id: u256, voter: ContractAddress) -> bool;
    fn proposals(proposal_id: u256) -> ContractAddress;
    fn get_proposal_status(proposal_id: u256) -> u8;
}

#[contract]
mod space {
    use super::ISpace;
    use starknet::ContractAddress;
    use super::Strategy;


    struct Storage {
        _owner: ContractAddress,
        _max_voting_duration: u256,
        _min_voting_duration: u256,
        _next_proposal_id: u256,
        _voting_delay: u256,
        _active_voting_strategies: u256,
        _voting_strategies: LegacyMap::<u8, Strategy>,
        _next_voting_strategy_index: u8,
        _proposal_validation_strategy: Strategy,
        _authenticators: LegacyMap::<ContractAddress, bool>,
        _proposals: LegacyMap::<u256, ContractAddress>, // TODO proposal struct
        _vote_power: LegacyMap::<(u256, u8), u256>, // TODO choice enum
        _vote_registry: LegacyMap::<(u256, ContractAddress), bool>,
    }

    #[constructor]
    fn constructor(
        _owner: ContractAddress,
        _max_voting_duration: u256,
        _min_voting_duration: u256,
        _voting_delay: u256,
        _voting_strategies: Array<Strategy>,
        _proposal_validation_strategy: Strategy
    ) {
        _owner::write(_owner);
        _set_max_voting_duration(_max_voting_duration);
        _set_min_voting_duration(_min_voting_duration);
        _set_voting_delay(_voting_delay);
        _set_proposal_validation_strategy(_proposal_validation_strategy);
    }

    #[view]
    fn owner() -> ContractAddress {
        _owner::read()
    }

    #[view]
    fn max_voting_duration() -> u256 {
        _max_voting_duration::read()
    }

    #[view]
    fn min_voting_duration() -> u256 {
        _min_voting_duration::read()
    }

    #[view]
    fn next_proposal_id() -> u256 {
        _next_proposal_id::read()
    }

    #[view]
    fn voting_delay() -> u256 {
        _voting_delay::read()
    }

    #[view]
    fn proposal_validation_strategy() -> Strategy {
        _proposal_validation_strategy::read()
    }

    /// 
    /// Internals
    ///

    fn _set_max_voting_duration(_max_voting_duration: u256) {
        _max_voting_duration::write(_max_voting_duration);
    }

    fn _set_min_voting_duration(_min_voting_duration: u256) {
        _min_voting_duration::write(_min_voting_duration);
    }

    fn _set_voting_delay(_voting_delay: u256) {
        _voting_delay::write(_voting_delay);
    }

    fn _set_proposal_validation_strategy(_proposal_validation_strategy: Strategy) {
        _proposal_validation_strategy::write(_proposal_validation_strategy);
    }
// fn _add_voting_strategies(_voting_strategies: Array<Strategy>) {
//     let index = next_voting_strategy_index::read();
//     voting_strategies::write(index, _voting_strategy);
//     next_voting_strategy_index::write(index + 1_u8);
// }

// fn _remove_voting_strategies(_voting_strategies: Array<Strategy>) {
//     let index = next_voting_strategy_index::read();
//     voting_strategies::write(index, _voting_strategy);
//     next_voting_strategy_index::write(index + 1_u8);
// }

// fn _add_authenticators(_authenticators: Array<ContractAddress>) {
//     for authenticator in _authenticators.iter() {
//         authenticators::write(authenticator, true);
//     }
// }

// fn _remove_authenticators(_authenticators: Array<ContractAddress>) {
//     for authenticator in _authenticators.iter() {
//         authenticators::write(authenticator, false);
//     }
// }
}
