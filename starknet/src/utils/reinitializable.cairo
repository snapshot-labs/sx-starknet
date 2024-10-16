/// A helper module for initializing / re-initializing.
#[starknet::component]
mod ReinitializableComponent {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        Reinitializable_initialized: bool
    }

    // Event is needed to derive PartialEq on it so we can test it in other modules.
    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {}

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        /// Initialize the contract. Must not have been initialized before.
        fn initialize(ref self: ComponentState<TContractState>) {
            self.not_initialized();
            self.Reinitializable_initialized.write(true);
        }

        /// Reset the initialization state of the contract, allowing it to be initialized again in the future.
        fn reset(ref self: ComponentState<TContractState>) {
            self.Reinitializable_initialized.write(false);
        }

        /// Asserts that the contract has been initialized.
        fn initialized(self: @ComponentState<TContractState>) {
            assert(self.Reinitializable_initialized.read() == true, 'Not Initialized');
        }

        /// Asserts that the contract has not been initialized.
        fn not_initialized(self: @ComponentState<TContractState>) {
            assert(self.Reinitializable_initialized.read() == false, 'Already Initialized');
        }
    }
}
