use starknet::{ContractAddress, EthAddress};
use starknet::SyscallResult;
use sx::types::{Strategy, IndexedStrategy, Choice};

#[starknet::interface]
trait IEthSigAuthenticator<TContractState> {
    fn authenticate_propose(
        ref self: TContractState,
        r: u256,
        s: u256,
        v: u32,
        space: ContractAddress,
        author: EthAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>,
        metadata_URI: Array<felt252>,
        salt: u256,
    );
    fn authenticate_vote(
        ref self: TContractState,
        r: u256,
        s: u256,
        v: u32,
        space: ContractAddress,
        voter: EthAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>,
        metadata_URI: Array<felt252>,
    );
    fn authenticate_update_proposal(
        ref self: TContractState,
        r: u256,
        s: u256,
        v: u32,
        space: ContractAddress,
        author: EthAddress,
        proposal_id: u256,
        execution_strategy: Strategy,
        metadata_URI: Array<felt252>,
        salt: u256
    );
}

#[starknet::contract]
mod EthSigAuthenticator {
    use super::IEthSigAuthenticator;
    use starknet::{ContractAddress, EthAddress, syscalls::call_contract_syscall};
    use array::{ArrayTrait, SpanTrait};
    use option::OptionTrait;
    use traits::{Into, TryInto};
    use integer::u128_byte_reverse;
    use sx::space::space::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::types::{Strategy, IndexedStrategy, Choice, UserAddress};
    use sx::utils::{signatures, legacy_hash::LegacyHashEthAddress};

    use core::keccak;
    use core::integer;

    use sx::utils::endian::{into_le_u64_array, ByteReverse};


    #[storage]
    struct Storage {
        _domain_hash: u256,
        _used_salts: LegacyMap::<(EthAddress, u256), bool>
    }

    #[external(v0)]
    impl EthSigAuthenticator of IEthSigAuthenticator<ContractState> {
        fn authenticate_propose(
            ref self: ContractState,
            r: u256,
            s: u256,
            v: u32,
            space: ContractAddress,
            author: EthAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            metadata_URI: Array<felt252>,
            salt: u256,
        ) {
            signatures::verify_propose_sig(
                r,
                s,
                v,
                self._domain_hash.read(),
                space,
                author,
                @execution_strategy,
                user_proposal_validation_params.span(),
                metadata_URI.span(),
                salt,
            );
            self._used_salts.write((author, salt), true);
        // ISpaceDispatcher {
        //     contract_address: space
        // }
        //     .propose(
        //         UserAddress::Ethereum(author),
        //         execution_strategy,
        //         user_proposal_validation_params,
        //         metadata_URI
        //     );
        }

        fn authenticate_vote(
            ref self: ContractState,
            r: u256,
            s: u256,
            v: u32,
            space: ContractAddress,
            voter: EthAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Array<IndexedStrategy>,
            metadata_URI: Array<felt252>,
        ) {
            signatures::verify_vote_sig(
                r,
                s,
                v,
                self._domain_hash.read(),
                space,
                voter,
                proposal_id,
                choice,
                user_voting_strategies.span(),
                metadata_URI.span(),
            );
        // No need to check salts here, as double voting is prevented by the space itself.

        // No need to check salts here, as double voting is prevented by the space itself.

        // ISpaceDispatcher {
        //     contract_address: space
        // }
        //     .vote(
        //         UserAddress::Ethereum(voter),
        //         proposal_id,
        //         choice,
        //         user_voting_strategies,
        //         metadata_URI
        //     );
        }

        fn authenticate_update_proposal(
            ref self: ContractState,
            r: u256,
            s: u256,
            v: u32,
            space: ContractAddress,
            author: EthAddress,
            proposal_id: u256,
            execution_strategy: Strategy,
            metadata_URI: Array<felt252>,
            salt: u256
        ) {
            signatures::verify_update_proposal_sig(
                r,
                s,
                v,
                self._domain_hash.read(),
                space,
                author,
                proposal_id,
                @execution_strategy,
                metadata_URI.span(),
                salt
            );
            self._used_salts.write((author, salt), true);
        // ISpaceDispatcher {
        //     contract_address: space
        // }
        //     .update_proposal(
        //         UserAddress::Ethereum(author), proposal_id, execution_strategy, metadata_URI
        //     );
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self._domain_hash.write(signatures::get_domain_hash());
    }
}
