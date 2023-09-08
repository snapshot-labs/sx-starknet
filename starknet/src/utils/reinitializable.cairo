#[starknet::interface]
trait IReinitializable<TContractState> {
    fn initialize(ref self: TContractState);
    fn reinitialize(ref self: TContractState);
    fn initialized(self: @TContractState);
    fn not_initialized(self: @TContractState);
}

/// A helper contract for initializing / re-initializing.
#[starknet::contract]
mod Reinitializable {
    use super::IReinitializable;
    use starknet::{ContractAddress, syscalls::call_contract_syscall};
    use core::array::{ArrayTrait, SpanTrait};

    #[storage]
    struct Storage {
        _initialized: bool
    }

    #[external(v0)]
    impl Reinitializable of IReinitializable<ContractState> {
        /// Initialize the contract. Must not have been initialized before.
        fn initialize(ref self: ContractState) {
            self.not_initialized();
            self._initialized.write(true);
        }

        /// Re-initialize the contract, allowing it to be initialized again in the future.
        fn reinitialize(ref self: ContractState) {
            self._initialized.write(false);
        }

        /// Asserts that the contract has been initialized.
        fn initialized(self: @ContractState) {
            assert(self._initialized.read() == true, 'Not Initialized');
        }

        /// Asserts that the contract has not been initialized.
        fn not_initialized(self: @ContractState) {
            assert(self._initialized.read() == false, 'Already Initialized');
        }
    }
}
