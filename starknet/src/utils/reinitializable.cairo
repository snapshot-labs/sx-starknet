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
        fn initialize(ref self: ContractState) {
            self.not_initialized();
            self._initialized.write(true);
        }

        fn reinitialize(ref self: ContractState) {
            self._initialized.write(false);
        }

        fn initialized(self: @ContractState) {
            assert(self._initialized.read() == true, 'Not Initialized');
        }

        fn not_initialized(self: @ContractState) {
            assert(self._initialized.read() == false, 'Already Initialized');
        }
    }
}
