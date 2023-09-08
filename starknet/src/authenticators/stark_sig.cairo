use starknet::ContractAddress;
use sx::types::{Strategy, IndexedStrategy, Choice};

/// See https://community.starknet.io/t/snip-off-chain-signatures-a-la-eip712/98029
#[starknet::interface]
trait IStarkSigAuthenticator<TContractState> {
    /// Authenticates a propose transaction using the starknet EIP712-equivalent signature scheme.
    /// 
    /// # Arguments
    ///
    /// * `signature` - The signature of message digest.
    /// * `target` - The address of the space contract.
    /// * `author` - The starkent address of the author of the proposal.
    /// * `metadata_uri` - The URI of the proposal metadata.
    /// * `execution_strategy` - The execution strategy of the proposal.
    /// * `user_proposal_validation_params` - The user proposal validation params of the proposal.
    /// * `salt` - The salt, used for replay protection.
    /// * `account_type` - The account type of the author ('snake' or 'camel').
    fn authenticate_propose(
        ref self: TContractState,
        signature: Array<felt252>,
        target: ContractAddress,
        author: ContractAddress,
        metadata_uri: Array<felt252>,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>,
        salt: felt252,
        account_type: felt252
    );


    /// Authenticates a vote transaction using the starknet EIP712-equivalent signature scheme.
    /// Salt is not needed because double voting is prevented by the space itself.
    ///
    /// # Arguments
    ///
    /// * `signature` - The signature of message digest.
    /// * `target` - The address of the space contract.
    /// * `voter` - The starkent address of the voter.
    /// * `proposal_id` - The id of the proposal.
    /// * `choice` - The choice of the voter.
    /// * `user_voting_strategies` - The user voting strategies of the voter.
    /// * `metadata_uri` - The URI of the proposal metadata.
    /// * `account_type` - The account type of the voter ('snake' or 'camel').
    ///
    fn authenticate_vote(
        ref self: TContractState,
        signature: Array<felt252>,
        target: ContractAddress,
        voter: ContractAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>,
        metadata_uri: Array<felt252>,
        account_type: felt252
    );

    /// Authenticates an update proposal transaction using the starknet EIP712-equivalent signature scheme.
    ///
    /// # Arguments
    ///
    /// * `signature` - The signature of message digest.
    /// * `target` - The address of the space contract.
    /// * `author` - The starkent address of the author of the proposal.
    /// * `proposal_id` - The id of the proposal.
    /// * `execution_strategy` - The execution strategy of the proposal.
    /// * `metadata_uri` - The URI of the proposal metadata.
    /// * `salt` - The salt, used for replay protection.
    /// * `account_type` - The account type of the author ('snake' or 'camel').
    fn authenticate_update_proposal(
        ref self: TContractState,
        signature: Array<felt252>,
        target: ContractAddress,
        author: ContractAddress,
        proposal_id: u256,
        execution_strategy: Strategy,
        metadata_uri: Array<felt252>,
        salt: felt252,
        account_type: felt252
    );
}

#[starknet::contract]
mod StarkSigAuthenticator {
    use super::IStarkSigAuthenticator;
    use starknet::{ContractAddress, info};
    use sx::{
        space::space::{ISpaceDispatcher, ISpaceDispatcherTrait},
        types::{Strategy, IndexedStrategy, UserAddress, Choice}, utils::stark_eip712
    };

    #[storage]
    struct Storage {
        _domain_hash: felt252,
        _used_salts: LegacyMap::<(ContractAddress, felt252), bool>
    }

    #[external(v0)]
    impl StarkSigAuthenticator of IStarkSigAuthenticator<ContractState> {
        fn authenticate_propose(
            ref self: ContractState,
            signature: Array<felt252>,
            target: ContractAddress,
            author: ContractAddress,
            metadata_uri: Array<felt252>,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            salt: felt252,
            account_type: felt252
        ) {
            assert(!self._used_salts.read((author, salt)), 'Salt Already Used');

            stark_eip712::verify_propose_sig(
                self._domain_hash.read(),
                signature,
                target,
                author,
                metadata_uri.span(),
                @execution_strategy,
                user_proposal_validation_params.span(),
                salt,
                account_type
            );

            self._used_salts.write((author, salt), true);
            ISpaceDispatcher { contract_address: target }
                .propose(
                    UserAddress::Starknet(author),
                    metadata_uri,
                    execution_strategy,
                    user_proposal_validation_params,
                );
        }

        fn authenticate_vote(
            ref self: ContractState,
            signature: Array<felt252>,
            target: ContractAddress,
            voter: ContractAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Array<IndexedStrategy>,
            metadata_uri: Array<felt252>,
            account_type: felt252
        ) {
            // No need to check salts here, as double voting is prevented by the space itself.

            stark_eip712::verify_vote_sig(
                self._domain_hash.read(),
                signature,
                target,
                voter,
                proposal_id,
                choice,
                user_voting_strategies.span(),
                metadata_uri.span(),
                account_type
            );

            ISpaceDispatcher { contract_address: target }
                .vote(
                    UserAddress::Starknet(voter),
                    proposal_id,
                    choice,
                    user_voting_strategies,
                    metadata_uri,
                );
        }

        fn authenticate_update_proposal(
            ref self: ContractState,
            signature: Array<felt252>,
            target: ContractAddress,
            author: ContractAddress,
            proposal_id: u256,
            execution_strategy: Strategy,
            metadata_uri: Array<felt252>,
            salt: felt252,
            account_type: felt252
        ) {
            assert(!self._used_salts.read((author, salt)), 'Salt Already Used');

            stark_eip712::verify_update_proposal_sig(
                self._domain_hash.read(),
                signature,
                target,
                author,
                proposal_id,
                @execution_strategy,
                metadata_uri.span(),
                salt,
                account_type
            );

            self._used_salts.write((author, salt), true);
            ISpaceDispatcher { contract_address: target }
                .update_proposal(
                    UserAddress::Starknet(author), proposal_id, execution_strategy, metadata_uri
                );
        }
    }
    #[constructor]
    fn constructor(ref self: ContractState, name: felt252, version: felt252) {
        self._domain_hash.write(stark_eip712::get_domain_hash(name, version));
    }
}
