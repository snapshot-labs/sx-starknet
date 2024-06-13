use starknet::ContractAddress;

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
    use starknet::{ContractAddress, syscalls};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl VanillaAuthenticator of IVanillaAuthenticator<ContractState> {
        fn authenticate(
            ref self: ContractState,
            target: ContractAddress,
            selector: felt252,
            data: Array<felt252>
        ) {
            // TODO: use if let Err(e) once it's supported
            match syscalls::call_contract_syscall(target, selector, data.span()) {
                Result::Ok(_) => {},
                Result::Err(a) => { assert(false, *a[0]); },
            };
        }
    }
}
