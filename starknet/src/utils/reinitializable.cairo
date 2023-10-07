/// A helper module for initializing / re-initializing.
#[starknet::contract]
mod Reinitializable {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        _initialized: bool
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Initialize the contract. Must not have been initialized before.
        fn initialize(ref self: ContractState) {
            self.not_initialized();
            self._initialized.write(true);
        }

        /// Re-initialize the contract, allowing it to be initialized again in the future.
        fn reset(ref self: ContractState) {
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
