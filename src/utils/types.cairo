use array::ArrayTrait;
use serde::Serde;
use traits::{PartialEq, TryInto, Into};
use option::OptionTrait;
use clone::Clone;
use integer::U8IntoU128;
use starknet::{
    ContractAddress, StorageAccess, StorageBaseAddress, SyscallResult, storage_write_syscall,
    storage_read_syscall, storage_address_from_base_and_offset, storage_base_address_from_felt252,
    contract_address::Felt252TryIntoContractAddress, syscalls::deploy_syscall,
    class_hash::Felt252TryIntoClassHash
};
use sx::utils::math::{U256Zeroable, pow};

impl U8ArrayIntoFelt252Array of Into<Array<u8>, Array<felt252>> {
    fn into(self: Array<u8>) -> Array<felt252> {
        let mut arr = ArrayTrait::<felt252>::new();
        let mut i = 0_usize;
        loop {
            if i >= self.len() {
                break ();
            }
            arr.append((*self.at(i)).into());
            i += 1;
        };
        arr
    }
}

#[derive(Option, Clone, Drop, Serde)]
struct Strategy {
    address: ContractAddress,
    params: Array<u8>,
}

#[derive(Option, Clone, Drop, Serde)]
struct IndexedStrategy {
    index: u8,
    params: Array<u8>,
}

/// NOTE: Using u64 for timestamps instead of u32 which we use in sx-evm. can change if needed.
#[derive(Clone, Drop, Serde)]
struct Proposal {
    snapshot_timestamp: u64,
    start_timestamp: u64,
    min_end_timestamp: u64,
    max_end_timestamp: u64,
    execution_payload_hash: felt252,
    execution_strategy: ContractAddress,
    author: ContractAddress,
    finalization_status: u8,
    active_voting_strategies: u256
}

impl StorageAccessProposal of StorageAccess<Proposal> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Proposal> {
        Result::Ok(
            Proposal {
                snapshot_timestamp: StorageAccess::read(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 0_u8).into()
                    )
                )?,
                start_timestamp: StorageAccess::read(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 1_u8).into()
                    )
                )?,
                min_end_timestamp: StorageAccess::read(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 2_u8).into()
                    )
                )?,
                max_end_timestamp: StorageAccess::read(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 3_u8).into()
                    )
                )?,
                execution_payload_hash: StorageAccess::read(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 4_u8).into()
                    )
                )?,
                execution_strategy: StorageAccess::read(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 5_u8).into()
                    )
                )?,
                author: StorageAccess::read(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 6_u8).into()
                    )
                )?,
                finalization_status: StorageAccess::read(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 7_u8).into()
                    )
                )?,
                active_voting_strategies: StorageAccess::read(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 8_u8).into()
                    )
                )?
            }
        )
    }

    fn write(address_domain: u32, base: StorageBaseAddress, value: Proposal) -> SyscallResult<()> {
        StorageAccess::write(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            ),
            value.snapshot_timestamp
        );

        StorageAccess::write(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 1_u8).into()
            ),
            value.start_timestamp
        );

        StorageAccess::write(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 2_u8).into()
            ),
            value.min_end_timestamp
        );

        StorageAccess::write(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 3_u8).into()
            ),
            value.max_end_timestamp
        );

        StorageAccess::write(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 4_u8).into()
            ),
            value.execution_payload_hash
        );

        StorageAccess::write(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 5_u8).into()
            ),
            value.execution_strategy
        );

        StorageAccess::write(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 6_u8).into()
            ),
            value.author
        );

        StorageAccess::write(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 7_u8).into()
            ),
            value.finalization_status
        );

        StorageAccess::write(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 8_u8).into()
            ),
            value.active_voting_strategies
        )
    }
}

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

trait IndexedStrategyTrait {
    fn assert_no_duplicates(self: @Array<IndexedStrategy>);
}

impl IndexedStrategyImpl of IndexedStrategyTrait {
    fn assert_no_duplicates(self: @Array<IndexedStrategy>) {
        if self.len() < 2 {
            return ();
        }

        let mut bit_map = U256Zeroable::zero();
        let mut i = 0_usize;
        loop {
            if i >= self.len() {
                break ();
            }
            // Check that bit at index `strats[i].index` is not set.
            let s = pow(u256 { low: 2_u128, high: 0_u128 }, *self.at(i).index);

            assert((bit_map & s) == u256 { low: 1_u128, high: 0_u128 }, 'Duplicate Found');
            // Update aforementioned bit.
            bit_map = bit_map | s;
            i += 1;
        };
    }
}
