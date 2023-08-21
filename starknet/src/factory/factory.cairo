use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
trait IFactory<TContractState> {
    fn deploy(
        self: @TContractState,
        class_hash: ClassHash,
        contract_address_salt: felt252,
        initialize_calldata: Span<felt252>
    ) -> ContractAddress;
}


#[starknet::contract]
mod Factory {
    use super::IFactory;
    use starknet::{
        ContractAddress, ClassHash, contract_address_const,
        syscalls::{deploy_syscall, call_contract_syscall}
    };
    use result::ResultTrait;
    use array::{ArrayTrait, SpanTrait};
    use sx::utils::constants::INITIALIZE_SELECTOR;

    #[event]
    fn SpaceDeployed(class_hash: ClassHash, space_address: ContractAddress) {}

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl Factory of IFactory<ContractState> {
        fn deploy(
            self: @ContractState,
            class_hash: ClassHash,
            contract_address_salt: felt252,
            initialize_calldata: Span<felt252>
        ) -> ContractAddress {
            let (space_address, _) = deploy_syscall(
                class_hash, contract_address_salt, array![].span(), false
            )
                .unwrap();

            // Call initializer. 
            call_contract_syscall(space_address, INITIALIZE_SELECTOR, initialize_calldata)
                .unwrap_syscall();

            SpaceDeployed(class_hash, space_address);

            space_address
        }
    }
}
