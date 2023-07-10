use array::ArrayTrait;
use result::ResultTrait;
use serde::Serde;
use traits::{PartialEq, TryInto, Into};
use hash::LegacyHash;
use option::OptionTrait;
use clone::Clone;
use integer::{U8IntoU128};
use starknet::{
    ContractAddress, StorageAccess, StorageBaseAddress, SyscallResult, storage_write_syscall,
    storage_read_syscall, storage_address_from_base_and_offset, storage_base_address_from_felt252,
    contract_address::Felt252TryIntoContractAddress, syscalls::deploy_syscall,
    class_hash::Felt252TryIntoClassHash
};
use sx::utils::math::pow;

impl Felt252ArrayIntoU256Array of Into<Array<felt252>, Array<u256>> {
    fn into(self: Array<felt252>) -> Array<u256> {
        let mut arr = ArrayTrait::<u256>::new();
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

#[derive(Copy, Drop, Serde)]
enum Choice {
    Against: (),
    For: (),
    Abstain: (),
}

#[derive(Copy, Drop, Serde, PartialEq)]
enum FinalizationStatus {
    Pending: (),
    Executed: (),
    Cancelled: (),
}

#[derive(Copy, Drop, Serde, PartialEq)]
enum ProposalStatus {
    VotingDelay: (),
    VotingPeriod: (),
    VotingPeriodAccepted: (),
    Accepted: (),
    Executed: (),
    Rejected: (),
    Cancelled: ()
}

impl ChoiceIntoU8 of Into<Choice, u8> {
    fn into(self: Choice) -> u8 {
        match self {
            Choice::Against(_) => 0_u8,
            Choice::For(_) => 1_u8,
            Choice::Abstain(_) => 2_u8,
        }
    }
}

impl ChoiceIntoU256 of Into<Choice, u256> {
    fn into(self: Choice) -> u256 {
        ChoiceIntoU8::into(self).into()
    }
}

impl U8IntoFinalizationStatus of TryInto<u8, FinalizationStatus> {
    fn try_into(self: u8) -> Option<FinalizationStatus> {
        if self == 0_u8 {
            Option::Some(FinalizationStatus::Pending(()))
        } else if self == 1_u8 {
            Option::Some(FinalizationStatus::Executed(()))
        } else if self == 2_u8 {
            Option::Some(FinalizationStatus::Cancelled(()))
        } else {
            Option::None(())
        }
    }
}

impl FinalizationStatusIntoU8 of Into<FinalizationStatus, u8> {
    fn into(self: FinalizationStatus) -> u8 {
        match self {
            FinalizationStatus::Pending(_) => 0_u8,
            FinalizationStatus::Executed(_) => 1_u8,
            FinalizationStatus::Cancelled(_) => 2_u8,
        }
    }
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

impl LegacyHashChoice of LegacyHash<Choice> {
    fn hash(state: felt252, value: Choice) -> felt252 {
        LegacyHash::hash(state, ChoiceIntoU8::into(value))
    }
}

#[derive(Option, Clone, Drop, Serde, StorageAccess)]
struct Strategy {
    address: ContractAddress,
    params: Array<felt252>,
}

impl PartialEqStrategy of PartialEq<Strategy> {
    fn eq(lhs: @Strategy, rhs: @Strategy) -> bool {
        lhs.address == rhs.address
            && poseidon::poseidon_hash_span(
                lhs.params.span()
            ) == poseidon::poseidon_hash_span(rhs.params.span())
    }

    fn ne(lhs: @Strategy, rhs: @Strategy) -> bool {
        !(lhs.clone() == rhs.clone())
    }
}

#[derive(Option, Clone, Drop, Serde)]
struct IndexedStrategy {
    index: u8,
    params: Array<felt252>,
}

/// NOTE: Using u64 for timestamps instead of u32 which we use in sx-evm. can change if needed.
#[derive(Clone, Drop, Serde, PartialEq, StorageAccess)]
struct Proposal {
    snapshot_timestamp: u64,
    start_timestamp: u64,
    min_end_timestamp: u64,
    max_end_timestamp: u64,
    execution_payload_hash: felt252,
    execution_strategy: ContractAddress,
    author: ContractAddress,
    finalization_status: FinalizationStatus,
    active_voting_strategies: u256
}

// TODO: Should eventually be able to derive the StorageAccess trait on the structs and enum 
// cant atm as the derive only works for simple structs 

impl StorageAccessFinalizationStatus of StorageAccess<FinalizationStatus> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<FinalizationStatus> {
        match StorageAccess::read(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            )
        ) {
            Result::Ok(num) => {
                Result::Ok(U8IntoFinalizationStatus::try_into(num).unwrap())
            },
            Result::Err(err) => Result::Err(err)
        }
    }

    fn write(
        address_domain: u32, base: StorageBaseAddress, value: FinalizationStatus
    ) -> SyscallResult<()> {
        StorageAccess::write(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            ),
            FinalizationStatusIntoU8::into(value)
        )
    }

    fn read_at_offset_internal(
        address_domain: u32, base: StorageBaseAddress, offset: u8
    ) -> SyscallResult<FinalizationStatus> {
        match StorageAccess::read_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            ),
            offset
        ) {
            Result::Ok(num) => {
                Result::Ok(U8IntoFinalizationStatus::try_into(num).unwrap())
            },
            Result::Err(err) => Result::Err(err)
        }
    }

    fn write_at_offset_internal(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: FinalizationStatus
    ) -> SyscallResult<()> {
        StorageAccess::write_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            ),
            offset,
            FinalizationStatusIntoU8::into(value)
        )
    }

    fn size_internal(value: FinalizationStatus) -> u8 {
        1_u8
    }
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

    fn read_at_offset_internal(
        address_domain: u32, base: StorageBaseAddress, offset: u8
    ) -> SyscallResult<Proposal> {
        Result::Ok(
            Proposal {
                snapshot_timestamp: StorageAccess::read_at_offset_internal(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 0_u8).into()
                    ),
                    offset
                )?,
                start_timestamp: StorageAccess::read_at_offset_internal(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 1_u8).into()
                    ),
                    offset
                )?,
                min_end_timestamp: StorageAccess::read_at_offset_internal(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 2_u8).into()
                    ),
                    offset
                )?,
                max_end_timestamp: StorageAccess::read_at_offset_internal(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 3_u8).into()
                    ),
                    offset
                )?,
                execution_payload_hash: StorageAccess::read_at_offset_internal(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 4_u8).into()
                    ),
                    offset
                )?,
                execution_strategy: StorageAccess::read_at_offset_internal(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 5_u8).into()
                    ),
                    offset
                )?,
                author: StorageAccess::read_at_offset_internal(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 6_u8).into()
                    ),
                    offset
                )?,
                finalization_status: StorageAccess::read_at_offset_internal(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 7_u8).into()
                    ),
                    offset
                )?,
                active_voting_strategies: StorageAccess::read_at_offset_internal(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 8_u8).into()
                    ),
                    offset
                )?
            }
        )
    }

    fn write_at_offset_internal(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: Proposal
    ) -> SyscallResult<()> {
        StorageAccess::write_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            ),
            offset,
            value.snapshot_timestamp
        );

        StorageAccess::write_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 1_u8).into()
            ),
            offset,
            value.start_timestamp
        );

        StorageAccess::write_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 2_u8).into()
            ),
            offset,
            value.min_end_timestamp
        );

        StorageAccess::write_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 3_u8).into()
            ),
            offset,
            value.max_end_timestamp
        );

        StorageAccess::write_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 4_u8).into()
            ),
            offset,
            value.execution_payload_hash
        );

        StorageAccess::write_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 5_u8).into()
            ),
            offset,
            value.execution_strategy
        );

        StorageAccess::write_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 6_u8).into()
            ),
            offset,
            value.author
        );

        StorageAccess::write_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 7_u8).into()
            ),
            offset,
            value.finalization_status
        );

        StorageAccess::write_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 8_u8).into()
            ),
            offset,
            value.active_voting_strategies
        )
    }

    fn size_internal(value: Proposal) -> u8 {
        9_u8
    }
}

impl StorageAccessFeltArray of StorageAccess<Array<felt252>> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Array<felt252>> {
        let length = StorageAccess::read(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            )
        )?;

        let mut arr = ArrayTrait::<felt252>::new();
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

    fn write(
        address_domain: u32, base: StorageBaseAddress, value: Array<felt252>
    ) -> SyscallResult<()> {
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

    fn read_at_offset_internal(
        address_domain: u32, base: StorageBaseAddress, offset: u8
    ) -> SyscallResult<Array<felt252>> {
        let length = StorageAccess::read_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            ),
            offset
        )?;

        let mut arr = ArrayTrait::<felt252>::new();
        let mut i = 0_usize;
        loop {
            if i >= length {
                break ();
            }

            match StorageAccess::read_at_offset_internal(
                address_domain,
                storage_base_address_from_felt252(
                    storage_address_from_base_and_offset(base, 0).into()
                ),
                offset
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

    fn write_at_offset_internal(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: Array<felt252>
    ) -> SyscallResult<()> {
        // Write length at offset 0
        StorageAccess::write_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            ),
            offset,
            value.len()
        );

        // Write values at offsets 1..value.len()
        let mut i = 1_usize;
        loop {
            if i >= value.len() {
                break ();
            }
            StorageAccess::write_at_offset_internal(
                address_domain,
                storage_base_address_from_felt252(
                    storage_address_from_base_and_offset(base, i.try_into().unwrap()).into()
                ),
                offset,
                *value.at(i)
            );
            i += 1;
        };
        Result::Ok(()) //TODO: what to return here? 
    }

    fn size_internal(value: Array<felt252>) -> u8 {
        // Add 1 for the length
        value.len().try_into().unwrap() + 1
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

    fn read_at_offset_internal(
        address_domain: u32, base: StorageBaseAddress, offset: u8
    ) -> SyscallResult<Strategy> {
        Result::Ok(
            Strategy {
                address: StorageAccess::read_at_offset_internal(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 0_u8).into()
                    ),
                    offset
                )?,
                params: StorageAccess::read_at_offset_internal(
                    address_domain,
                    storage_base_address_from_felt252(
                        storage_address_from_base_and_offset(base, 1_u8).into()
                    ),
                    offset
                )?
            }
        )
    }

    fn write_at_offset_internal(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: Strategy
    ) -> SyscallResult<()> {
        // Write value.address at offset 0
        StorageAccess::write_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 0_u8).into()
            ),
            offset,
            value.address
        );

        // Write value.params at offset 1
        StorageAccess::write_at_offset_internal(
            address_domain,
            storage_base_address_from_felt252(
                storage_address_from_base_and_offset(base, 1_u8).into()
            ),
            offset,
            value.params
        )
    }

    fn size_internal(value: Strategy) -> u8 {
        // Add 1 for the strategy address
        StorageAccess::size_internal(value.params) + 1
    }
}

trait IndexedStrategyTrait {
    fn assert_no_duplicate_indices(self: @Array<IndexedStrategy>);
}

impl IndexedStrategyImpl of IndexedStrategyTrait {
    fn assert_no_duplicate_indices(self: @Array<IndexedStrategy>) {
        if self.len() < 2 {
            return ();
        }

        let mut bit_map = u256 { low: 0_u128, high: 0_u128 };
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
