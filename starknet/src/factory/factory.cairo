use starknet::{ContractAddress, ClassHash, SyscallResult};

#[starknet::interface]
trait IFactory<TContractState> {
    fn deploy(
        ref self: TContractState,
        class_hash: ClassHash,
        initialize_calldata: Span<felt252>,
        contract_address_salt: felt252,
    ) -> SyscallResult<ContractAddress>;
}


#[starknet::contract]
mod Factory {
    use super::IFactory;
    use starknet::{ContractAddress, ClassHash, syscalls, SyscallResult};
    use sx::utils::constants::INITIALIZE_SELECTOR;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NewContractDeployed: NewContractDeployed
    }

    #[derive(Drop, starknet::Event)]
    struct NewContractDeployed {
        class_hash: ClassHash,
        contract_address: ContractAddress
    }

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl Factory of IFactory<ContractState> {
        fn deploy(
            ref self: ContractState,
            class_hash: ClassHash,
            initialize_calldata: Span<felt252>,
            contract_address_salt: felt252,
        ) -> SyscallResult<ContractAddress> {
            // We create the salt by hashing the user provided salt and the caller address
            // to avoid any frontrun attacks.
            let caller_address = starknet::info::get_caller_address().into();
            let salt_input = array![caller_address, contract_address_salt];
            let salt = poseidon::poseidon_hash_span(salt_input.span());

            let (space_address, _) = syscalls::deploy_syscall(
                class_hash, salt, array![].span(), false
            )?;

            // Call initializer. 
            syscalls::call_contract_syscall(
                space_address, INITIALIZE_SELECTOR, initialize_calldata
            )?;

            self
                .emit(
                    Event::NewContractDeployed(
                        NewContractDeployed { class_hash, contract_address: space_address }
                    )
                );

            Result::Ok(space_address)
        }
    }
}
