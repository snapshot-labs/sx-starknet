use starknet::ContractAddress;
use starknet::ClassHash;

#[starknet::interface]
trait IFactory<TContractState> {
    fn deploy(
        self: @TContractState,
        class_hash: ClassHash,
        contract_address_salt: felt252,
        calldata: Span<felt252>
    ) -> ContractAddress;
}


#[starknet::contract]
mod Factory {
    use super::IFactory;
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use starknet::syscalls::deploy_syscall;
    use starknet::ClassHash;
    use result::ResultTrait;

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
            calldata: Span<felt252>
        ) -> ContractAddress {
            let (space_address, _) = deploy_syscall(
                class_hash, contract_address_salt, calldata, false
            )
                .unwrap();
            // emit event
            SpaceDeployed(class_hash, space_address);

            space_address
        }
    }
}
