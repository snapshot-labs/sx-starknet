use integer::BoundedU8;
use starknet::{ContractAddress, StorageBaseAddress, Store, SyscallResult};
use starknet::SyscallResultTrait;

/// A strategy identified by an address
#[derive(Clone, Drop, Option, Serde, starknet::Store)]
struct Strategy {
    /// The strategy address.
    address: ContractAddress,
    /// The strategy parameters.
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

// TODO: Should eventually be able to derive the Store trait on the structs and enum 
// cant atm as the derive only works for simple structs I think
impl StoreFelt252Array of Store<Array<felt252>> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Array<felt252>> {
        StoreFelt252Array::read_at_offset(address_domain, base, 0)
    }

    fn write(
        address_domain: u32, base: StorageBaseAddress, value: Array<felt252>
    ) -> SyscallResult<()> {
        StoreFelt252Array::write_at_offset(address_domain, base, 0, value)
    }

    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, mut offset: u8
    ) -> SyscallResult<Array<felt252>> {
        let mut arr = array![];

        // Read the stored array's length. If the length is superior to 255, the read will fail.
        let len: u8 = Store::<u8>::read_at_offset(address_domain, base, offset)
            .expect('Storage Span too large');
        offset += Store::<u8>::size();

        // Sequentially read all stored elements and append them to the array.
        let exit = len * Store::<felt252>::size() + offset;
        loop {
            if offset >= exit {
                break;
            }

            let value = Store::<felt252>::read_at_offset(address_domain, base, offset).unwrap();
            arr.append(value);
            offset += Store::<felt252>::size();
        };

        // Return the array.
        Result::Ok(arr)
    }

    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, mut offset: u8, mut value: Array<felt252>
    ) -> SyscallResult<()> {
        // // Store the length of the array in the first storage slot.
        let len: u8 = value.len().try_into().expect('Storage - Span too large');
        Store::<u8>::write_at_offset(address_domain, base, offset, len).unwrap_syscall();
        offset += Store::<u8>::size();

        // Store the array elements sequentially
        loop {
            match value.pop_front() {
                Option::Some(element) => {
                    match Store::<felt252>::write_at_offset(address_domain, base, offset, element) {
                        Result::Ok(()) => {},
                        Result::Err(e) => { break Result::Err(e); }
                    }
                    offset += Store::<felt252>::size();
                },
                Option::None(_) => { break Result::Ok(()); }
            };
        }
    }

    fn size() -> u8 {
        /// Since the array is a dynamic type. We use its max size here. 
        BoundedU8::max()
    }
}

