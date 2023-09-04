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
            // TODO: use if let Err(e) once it's supported
            match call_contract_syscall(target, selector, data.span()) {
                Result::Ok(a) => {},
                Result::Err(a) => {
                    assert(false, *a[0]);
                },
            };
        }
    }
}
