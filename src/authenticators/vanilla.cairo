use starknet::ContractAddress;

#[abi]
trait IVanillaAuthenticator {
    fn authenticate(target: ContractAddress, selector: felt252, data: Array<felt252>);
}

#[contract]
mod VanillaAuthenticator {
    use super::IVanillaAuthenticator;
    use starknet::ContractAddress;
    use starknet::syscalls::call_contract_syscall;
    use core::array::{ArrayTrait, SpanTrait};

    impl VanillaAuthenticator of IVanillaAuthenticator {
        #[external]
        fn authenticate(
            target: ContractAddress, selector: felt252, data: Array<felt252>
        ) {
            call_contract_syscall(target, selector, data.span());
        }
    }
}
