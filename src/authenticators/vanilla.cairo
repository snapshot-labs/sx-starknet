use starknet::ContractAddress;

#[abi]
trait IVanillaAuthenticator {
    fn authenticate(target: ContractAddress, entry_point_selector: felt252, data: Array<felt252>);
}

#[contract]
mod VanillaAuthenticator {
    use starknet::ContractAddress;
    use starknet::syscalls::call_contract_syscall;
    use core::array::{ArrayTrait, SpanTrait};

    #[external]
    fn authenticate(target: ContractAddress, entry_point_selector: felt252, data: Array<felt252>) {
        call_contract_syscall(target, entry_point_selector, data.span());
    }
}
