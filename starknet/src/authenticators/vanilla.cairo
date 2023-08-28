use starknet::{ContractAddress, SyscallResult};

#[starknet::interface]
trait IVanillaAuthenticator<TContractState> {
    fn authenticate(
        ref self: TContractState, target: ContractAddress, selector: felt252, data: Array<felt252>
    );
}

#[starknet::contract]
mod VanillaAuthenticator {
    use super::IVanillaAuthenticator;
    use starknet::ContractAddress;
    use starknet::syscalls::call_contract_syscall;
    use core::array::{ArrayTrait, SpanTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl VanillaAuthenticator of IVanillaAuthenticator<ContractState> {
        fn authenticate(
            ref self: ContractState,
            target: ContractAddress,
            selector: felt252,
            data: Array<felt252>
        ) {
            call_contract_syscall(target, selector, data.span()).unwrap_syscall();
        }
    }
}
