use starknet::ContractAddress;
use starknet::SyscallResult;
use sx::utils::types::{Strategy, IndexedStrategy, Choice};

#[starknet::interface]
trait IStarkSigAuthenticator<TContractState> {
    fn authenticate_propose(
        ref self: TContractState,
        r: felt252,
        s: felt252,
        target: ContractAddress,
        author: ContractAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>,
        salt: felt252,
    );
    fn propose_hash(
        self: @TContractState,
        r: felt252,
        s: felt252,
        target: ContractAddress,
        author: ContractAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>,
        salt: felt252
    ) -> felt252;
    fn encoded_strategy(
            self: @TContractState,
            r: felt252,
            s: felt252,
            target: ContractAddress,
            author: ContractAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            salt: felt252,
    ) -> Array<felt252>;
}

#[starknet::contract]
mod StarkSigAuthenticator {
    use super::IStarkSigAuthenticator;
    use starknet::ContractAddress;
    use starknet::syscalls::call_contract_syscall;
    use core::array::{ArrayTrait, SpanTrait};
    use clone::Clone;
    use serde::Serde;
    use sx::space::space::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::utils::types::{Strategy, IndexedStrategy, Choice};
    use sx::utils::stark_signatures;

    #[storage]
    struct Storage {
        _domain_hash: felt252,
        _used_salts: LegacyMap::<(ContractAddress, felt252), bool>
    }

    #[external(v0)]
    impl StarkSigAuthenticator of IStarkSigAuthenticator<ContractState> {
        fn authenticate_propose(
            ref self: ContractState,
            r: felt252,
            s: felt252,
            target: ContractAddress,
            author: ContractAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            salt: felt252,
        ) {
            let msg_hash = stark_signatures::get_propose_digest(
                target, author, execution_strategy, user_proposal_validation_params, salt
            );
        // self._used_salts.write((author, salt), true);

        // ISpaceDispatcher {
        //     contract_address: target
        // }.propose(author, execution_strategy, user_proposal_validation_params);
        }

        fn propose_hash(
            self: @ContractState,
            r: felt252,
            s: felt252,
            target: ContractAddress,
            author: ContractAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            salt: felt252,
        ) -> felt252 {
            stark_signatures::get_propose_digest(
                target, author, execution_strategy, user_proposal_validation_params, salt
            )
        }

        fn encoded_strategy(
            self: @ContractState,
            r: felt252,
            s: felt252,
            target: ContractAddress,
            author: ContractAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            salt: felt252,
        ) -> Array<felt252> {
            let mut encoded_data = ArrayTrait::<felt252>::new();
            0x14c6b221e639b0d611fd0aab18c0c1e29079e17e0445bebd85b5cad1aaaee2b.serialize(ref encoded_data);
            execution_strategy.address.serialize(ref encoded_data);
            execution_strategy.params.serialize(ref encoded_data);
            encoded_data
        }

    }
// #[constructor]
// fn constructor(ref self: ContractState, name: felt252, version: felt252) {// TODO: domain hash is immutable so could be placed in the contract code instead of storage to save on reads.
// // self._domain_hash.write(signatures::get_domain_hash(name, version));
// }
}
