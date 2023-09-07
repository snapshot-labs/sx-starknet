use starknet::{ContractAddress, SyscallResult};

#[starknet::interface]
trait IVanillaAuthenticator<TContractState> {
    /// Forwards the call to the target contract, no questions asked.
    fn authenticate(
        ref self: TContractState, target: ContractAddress, selector: felt252, data: Array<felt252>
    );
}

#[starknet::contract]
mod VanillaAuthenticator {
    use super::IVanillaAuthenticator;
    use starknet::ContractAddress;
    use starknet::syscalls::call_contract_syscall;
    use debug::PrintTrait;

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
                    a.print();
                    assert(false, *a[0]);
                },
            };
        }
    }
}
