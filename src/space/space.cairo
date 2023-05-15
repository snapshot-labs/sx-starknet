use starknet::{
    ContractAddress, StorageAccess, StorageBaseAddress, SyscallResult, storage_write_syscall,
    storage_read_syscall, storage_address_from_base_and_offset, storage_base_address_from_felt252,
    contract_address::Felt252TryIntoContractAddress, syscalls::deploy_syscall,
    class_hash::Felt252TryIntoClassHash
};
use array::ArrayTrait;
use serde::Serde;
use traits::Into;
use traits::TryInto;
use traits::PartialEq;
use option::OptionTrait;
use clone::Clone;

#[derive(Clone, Drop, Serde)]
struct Strategy {
    address: ContractAddress,
    params: Array<u8>,
}

// #[derive(Drop, Serde)]
// struct Proposal {
//     snapshot_timestamp: u32,
//     start_timestamp: u32,
//     min_end_timestamp: u32,
//     max_end_timestamp: u32,
//     execution_payload_hash: u256,
//     execution_strategy: ContractAddress,
//     author: ContractAddress,
//     finalization_status: u8,
//     active_voting_strategies: u256
// }

impl StorageAccessU8Array of StorageAccess<Array<u8>> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Array<u8>> {
        let length = StorageAccess::read(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            )
        )?;

        let mut arr = ArrayTrait::<u8>::new();
        let mut i = 0_usize;
        loop {
            if i >= length {
                break ();
            }

            match StorageAccess::read(
                address_domain,
                storage_base_address_from_felt252(
                    storage_address_from_base_and_offset(base, 0).into()
                )
            ) {
                Result::Ok(b) => arr.append(b),
                Result::Err(_) => {
                    break ();
                }
            }

            i += 1;
        };
        Result::Ok(arr)
    }

    fn write(address_domain: u32, base: StorageBaseAddress, value: Array<u8>) -> SyscallResult<()> {
        // Write length at offset 0
        StorageAccess::write(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            ),
            value.len()
        );

        // Write values at offsets 1..value.len()
        let mut i = 1_usize;
        loop {
            if i >= value.len() {
                break ();
            }
            StorageAccess::write(
                address_domain,
                storage_base_address_from_felt252(
                    storage_address_from_base_and_offset(base, i.try_into().unwrap()).into()
                ),
                *value.at(i)
            );
            i += 1;
        };
        Result::Ok(()) //TODO: what to return here? 
    }
}

impl StorageAccessStrategy of StorageAccess<Strategy> {
    // #[inline(always)]
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Strategy> {
        Result::Ok(
            Strategy {
                address: StorageAccess::read(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 0_u8).into()
                    )
                )?,
                params: StorageAccess::read(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 1_u8).into()
                    )
                )?
            }
        )
    }
    // #[inline(always)]
    fn write(address_domain: u32, base: StorageBaseAddress, value: Strategy) -> SyscallResult<()> {
        // Write value.address at offset 0
        StorageAccess::write(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            ),
            value.address
        );

        // Write value.params at offset 1
        StorageAccess::write(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 1_u8).into()
            ),
            value.params
        )
    }
}

impl StorageAccessStrategyArray of StorageAccess<Array<Strategy>> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Array<Strategy>> {
        let length = StorageAccess::read(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            )
        )?;

        let mut arr = ArrayTrait::<Strategy>::new();
        let mut i = 1_usize;
        loop {
            if i >= length {
                break ();
            }
            arr.append(
                StorageAccess::read(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, i.try_into().unwrap()).into()
                    )
                )?
            );
            i += 1;
        };
        Result::Ok(arr)
    }

    fn write(
        address_domain: u32, base: StorageBaseAddress, value: Array<Strategy>
    ) -> SyscallResult<()> {
        // Write length at offset 0
        StorageAccess::write(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            ),
            value.len()
        );

        // Write values at offsets 1.. 
        let mut i = 1_usize;
        loop {
            if i >= value.len() {
                break ();
            }
            // TODO: maybe I dont need to clone here? could use a span but need to impl that on Strategy
            StorageAccess::write(
                address_domain,
                storage_base_address_from_felt252(
                    storage_address_from_base_and_offset(base, i.try_into().unwrap()).into()
                ),
                value.at(i).clone()
            )?;
        };
        Result::Ok(())
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
    use starknet::syscalls::deploy_syscall;

    use super::StorageAccessU8Array;
    use super::StorageAccessStrategy;

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
        _proposal_validation_strategy: Strategy
    ) {
        _owner::write(_owner);
        _set_max_voting_duration(_max_voting_duration);
        _set_min_voting_duration(_min_voting_duration);
        _set_voting_delay(_voting_delay);
        // TODO: FIX THIS
        _set_proposal_validation_strategy(_proposal_validation_strategy);
    // _proposal_validation_strategy::write(_proposal_validation_strategy);
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

    // TODO: wont compile
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

mod Tests {
    use array::ArrayTrait;
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::ContractAddress;
    use starknet::syscalls::deploy_syscall;
    use starknet::contract_address_const;
    use super::space;
    use super::Strategy;
    use traits::{Into, TryInto};
    use core::result::ResultTrait;
    use option::OptionTrait;
    use integer::u256_from_felt252;
    use clone::Clone;

    #[test]
    #[available_gas(1000000)]
    fn test_constructor() {
        let owner = contract_address_const::<1>();
        let max_voting_duration = u256_from_felt252(1);
        let min_voting_duration = u256_from_felt252(1);
        let voting_delay = u256_from_felt252(1);
        let proposal_validation_strategy = Strategy {
            address: contract_address_const::<1>(), params: ArrayTrait::<u8>::new()
        };

        space::constructor(
            owner,
            max_voting_duration,
            min_voting_duration,
            voting_delay,
            proposal_validation_strategy.clone()
        );

        assert(space::owner() == owner, 'owner should be set');
        assert(space::max_voting_duration() == max_voting_duration, 'max');
        assert(space::min_voting_duration() == min_voting_duration, 'min');
        assert(space::voting_delay() == voting_delay, 'voting_delay');
    // TODO: impl PartialEq for Strategy
    // assert(space::proposal_validation_strategy() == proposal_validation_strategy, 'proposal_validation_strategy');

    }
}

