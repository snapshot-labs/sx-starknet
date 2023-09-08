use core::starknet::SyscallResultTrait;
use starknet::{ContractAddress, get_tx_info, get_contract_address};
use sx::{
    types::{Strategy, IndexedStrategy, Choice},
    utils::{
        struct_hash::StructHash,
        constants::{
            STARKNET_MESSAGE, DOMAIN_TYPEHASH, PROPOSE_TYPEHASH, VOTE_TYPEHASH,
            UPDATE_PROPOSAL_TYPEHASH, ERC165_ACCOUNT_INTERFACE_ID, ERC165_OLD_ACCOUNT_INTERFACE_ID
        }
    },
    interfaces::{
        AccountABIDispatcher, AccountABIDispatcherTrait, AccountCamelABIDispatcher,
        AccountCamelABIDispatcherTrait
    }
};

/// Implementation of off-chain signature verification.
/// See https://community.starknet.io/t/snip-off-chain-signatures-a-la-eip712/98029

/// Verifies the signature of a propose by calling the account contract.
fn verify_propose_sig(
    domain_hash: felt252,
    signature: Array<felt252>,
    target: ContractAddress,
    author: ContractAddress,
    execution_strategy: @Strategy,
    user_proposal_validation_params: Span<felt252>,
    metadata_uri: Span<felt252>,
    salt: felt252,
    account_type: felt252,
) {
    let digest: felt252 = get_propose_digest(
        domain_hash,
        target,
        author,
        execution_strategy,
        user_proposal_validation_params,
        metadata_uri,
        salt
    );

    verify_signature(digest, signature, author, account_type);
}

/// Verifies the signature of a vote by calling the account contract.
fn verify_vote_sig(
    domain_hash: felt252,
    signature: Array<felt252>,
    target: ContractAddress,
    voter: ContractAddress,
    proposal_id: u256,
    choice: Choice,
    user_voting_strategies: Span<IndexedStrategy>,
    metadata_uri: Span<felt252>,
    account_type: felt252,
) {
    let digest: felt252 = get_vote_digest(
        domain_hash, target, voter, proposal_id, choice, user_voting_strategies, metadata_uri
    );
    verify_signature(digest, signature, voter, account_type);
}

/// Verifies the signature of an update proposal by calling the account contract.
fn verify_update_proposal_sig(
    domain_hash: felt252,
    signature: Array<felt252>,
    target: ContractAddress,
    author: ContractAddress,
    proposal_id: u256,
    execution_strategy: @Strategy,
    metadata_uri: Span<felt252>,
    salt: felt252,
    account_type: felt252,
) {
    let digest: felt252 = get_update_proposal_digest(
        domain_hash, target, author, proposal_id, execution_strategy, metadata_uri, salt
    );
    verify_signature(digest, signature, author, account_type);
}

/// Returns the digest of the propose calldata.
///
/// # Arguments
///
/// * `domain_hash` - The domain hash.
/// * `space` - The space contract address.
/// * `author` - The author address.
/// * `execution_strategy` - The execution strategy.
/// * `user_proposal_validation_params` - The user proposal validation params.
/// * `metadata_uri` - The metadata URI.
/// * `salt` - The salt (used for replay protection).
fn get_propose_digest(
    domain_hash: felt252,
    space: ContractAddress,
    author: ContractAddress,
    execution_strategy: @Strategy,
    user_proposal_validation_params: Span<felt252>,
    metadata_uri: Span<felt252>,
    salt: felt252
) -> felt252 {
    let mut encoded_data = array![];
    PROPOSE_TYPEHASH.serialize(ref encoded_data);
    space.serialize(ref encoded_data);
    author.serialize(ref encoded_data);
    execution_strategy.struct_hash().serialize(ref encoded_data);
    user_proposal_validation_params.struct_hash().serialize(ref encoded_data);
    metadata_uri.struct_hash().serialize(ref encoded_data);
    salt.serialize(ref encoded_data);
    hash_typed_data(domain_hash, encoded_data.span().struct_hash(), author)
}

/// Returns the digest of the vote calldata.
/// A `salt` is not needed in this function because a vote is only counted
/// once (verified at the space level in the `vote` function).
///
/// # Arguments
///
/// * `domain_hash` - The domain hash.
/// * `space` - The space contract address.
/// * `voter` - The voter address.
/// * `proposal_id` - The proposal id.
/// * `choice` - The choice.
/// * `user_voting_strategies` - The user voting strategies.
/// * `metadata_uri` - The metadata URI.
fn get_vote_digest(
    domain_hash: felt252,
    space: ContractAddress,
    voter: ContractAddress,
    proposal_id: u256,
    choice: Choice,
    user_voting_strategies: Span<IndexedStrategy>,
    metadata_uri: Span<felt252>,
) -> felt252 {
    let mut encoded_data = array![];
    VOTE_TYPEHASH.serialize(ref encoded_data);
    space.serialize(ref encoded_data);
    voter.serialize(ref encoded_data);
    proposal_id.struct_hash().serialize(ref encoded_data);
    choice.serialize(ref encoded_data);
    user_voting_strategies.struct_hash().serialize(ref encoded_data);
    metadata_uri.struct_hash().serialize(ref encoded_data);
    hash_typed_data(domain_hash, encoded_data.span().struct_hash(), voter)
}


/// Returns the digest of the update proposal calldata.
///
/// # Arguments
///
/// * `domain_hash` - The domain hash.
/// * `space` - The space contract address.
/// * `author` - The author address.
/// * `proposal_id` - The proposal id.
/// * `execution_strategy` - The execution strategy.
/// * `metadata_uri` - The metadata URI.
/// * `salt` - The salt (used for replay protection).
fn get_update_proposal_digest(
    domain_hash: felt252,
    space: ContractAddress,
    author: ContractAddress,
    proposal_id: u256,
    execution_strategy: @Strategy,
    metadata_uri: Span<felt252>,
    salt: felt252
) -> felt252 {
    let mut encoded_data = array![];
    UPDATE_PROPOSAL_TYPEHASH.serialize(ref encoded_data);
    space.serialize(ref encoded_data);
    author.serialize(ref encoded_data);
    proposal_id.struct_hash().serialize(ref encoded_data);
    execution_strategy.struct_hash().serialize(ref encoded_data);
    metadata_uri.struct_hash().serialize(ref encoded_data);
    salt.serialize(ref encoded_data);
    hash_typed_data(domain_hash, encoded_data.span().struct_hash(), author)
}


/// Returns the domain hash of the contract.
/// 
/// # Arguments
///
/// * `name` - The name of the domain.
/// * `version` - The version of the domain.
fn get_domain_hash(name: felt252, version: felt252) -> felt252 {
    let mut encoded_data = array![];
    DOMAIN_TYPEHASH.serialize(ref encoded_data);
    name.serialize(ref encoded_data);
    version.serialize(ref encoded_data);
    get_tx_info().unbox().chain_id.serialize(ref encoded_data);
    get_contract_address().serialize(ref encoded_data);
    encoded_data.span().struct_hash()
}

/// Hashes typed data according to the starknet equiavelnt to the EIP-712 specification.
/// 
/// # Arguments
///
/// * `domain_hash` - The domain hash.
/// * `message_hash` - The message hash.
/// * `signer` - The signer address.
fn hash_typed_data(
    domain_hash: felt252, message_hash: felt252, signer: ContractAddress
) -> felt252 {
    let mut encoded_data = array![];
    STARKNET_MESSAGE.serialize(ref encoded_data);
    domain_hash.serialize(ref encoded_data);
    signer.serialize(ref encoded_data);
    message_hash.serialize(ref encoded_data);
    encoded_data.span().struct_hash()
}

/// Verifies the signature of a message by calling the account contract.
/// This function does not return anything, but will panic if the signature is invalid.
///
/// # Arguments
///
/// * `digest` - The message digest.
/// * `signature` - The user-supplied signature of the digest.
/// * `account` - The account contract address.
/// * `account_type` - The account contract type (either 'snake' or 'camel'). Here for historical compatibility.
fn verify_signature(
    digest: felt252, signature: Array<felt252>, account: ContractAddress, account_type: felt252
) {
    if account_type == 'snake' {
        assert(
            AccountCamelABIDispatcher { contract_address: account }
                .supportsInterface(ERC165_ACCOUNT_INTERFACE_ID) == true,
            'Invalid Account'
        );
        AccountCamelABIDispatcher { contract_address: account }.isValidSignature(digest, signature);
    } else if account_type == 'camel' {
        assert(
            AccountABIDispatcher { contract_address: account }
                .supports_interface(ERC165_OLD_ACCOUNT_INTERFACE_ID) == true,
            'Invalid Account'
        );
        AccountABIDispatcher { contract_address: account }.is_valid_signature(digest, signature);
    } else {
        panic_with_felt252('Invalid Account Type');
    }
}
