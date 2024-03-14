#[starknet::interface]
trait IEthTxSessionKeyAuthenticator<TContractState> {
    fn authenticate_propose(
        ref self: TContractState,
        signature: Array<felt252>,
        space: ContractAddress,
        author: ContractAddress,
        metadata_uri: Array<felt252>,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>,
        salt: felt252,
        session_public_key: felt252
    );

    fn authenticate_vote(
        ref self: TContractState,
        signature: Array<felt252>,
        space: ContractAddress,
        voter: ContractAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>,
        metadata_uri: Array<felt252>,
        session_public_key: felt252
    );

    fn authenticate_update_proposal(
        ref self: TContractState,
        signature: Array<felt252>,
        space: ContractAddress,
        author: ContractAddress,
        proposal_id: u256,
        execution_strategy: Strategy,
        metadata_uri: Array<felt252>,
        salt: felt252,
        session_public_key: felt252
    );

    fn authorize_with_eth_tx(
        ref self: ContractState,
        eth_address: EthAddress,
        session_public_key: felt252,
        session_duration: u32
    ) {}

    fn revoke_with_owner_eth_tx(ref self: ContractState, session_public_key: felt252) {}


    fn revoke_with_session_key_sig(
        ref self: TContractState, sig: Array<felt252>, salt: felt252, session_public_key: felt252
    );
}
