use core::array::SpanTrait;
use starknet::{EthAddress, ContractAddress, get_contract_address, get_tx_info};
use array::{ArrayTrait};
use traits::Into;
use option::OptionTrait;
use core::keccak;
use box::BoxTrait;
use starknet::secp256_trait::{signature_from_vrs, verify_eth_signature, Signature};
use starknet::secp256k1::{Secp256k1Point, Secp256k1PointImpl};
use sx::types::{Strategy, IndexedStrategy, Choice};
use sx::utils::constants::{
    DOMAIN_TYPEHASH_LOW, DOMAIN_TYPEHASH_HIGH, ETHEREUM_PREFIX, PROPOSE_TYPEHASH_LOW,
    PROPOSE_TYPEHASH_HIGH, VOTE_TYPEHASH_LOW, VOTE_TYPEHASH_HIGH, UPDATE_PROPOSAL_TYPEHASH_LOW,
    UPDATE_PROPOSAL_TYPEHASH_HIGH, INDEXED_STRATEGY_TYPEHASH_LOW, INDEXED_STRATEGY_TYPEHASH_HIGH,
};
use sx::utils::math::{pow, pow_u128};
use sx::utils::endian::{into_le_u64_array, ByteReverse};
use sx::utils::keccak::KeccakStructHash;
use sx::utils::into::TIntoU256;

fn verify_propose_sig(
    r: u256,
    s: u256,
    v: u32,
    domain_hash: u256,
    target: ContractAddress,
    author: EthAddress,
    metadata_uri: Span<felt252>,
    execution_strategy: @Strategy,
    user_proposal_validation_params: Span<felt252>,
    salt: u256,
) {
    let digest: u256 = get_propose_digest(
        domain_hash,
        target,
        author,
        metadata_uri,
        execution_strategy,
        user_proposal_validation_params,
        salt
    );
    verify_eth_signature::<Secp256k1Point>(digest, signature_from_vrs(v, r, s), author);
}

fn verify_vote_sig(
    r: u256,
    s: u256,
    v: u32,
    domain_hash: u256,
    target: ContractAddress,
    voter: EthAddress,
    proposal_id: u256,
    choice: Choice,
    user_voting_strategies: Span<IndexedStrategy>,
    metadata_uri: Span<felt252>,
) {
    let digest: u256 = get_vote_digest(
        domain_hash, target, voter, proposal_id, choice, user_voting_strategies, metadata_uri
    );
    verify_eth_signature::<Secp256k1Point>(digest, signature_from_vrs(v, r, s), voter);
}

fn verify_update_proposal_sig(
    r: u256,
    s: u256,
    v: u32,
    domain_hash: u256,
    target: ContractAddress,
    author: EthAddress,
    proposal_id: u256,
    execution_strategy: @Strategy,
    metadata_uri: Span<felt252>,
    salt: u256
) {
    let digest: u256 = get_update_proposal_digest(
        domain_hash, target, author, proposal_id, execution_strategy, metadata_uri, salt
    );
    verify_eth_signature::<Secp256k1Point>(digest, signature_from_vrs(v, r, s), author);
}

fn get_propose_digest(
    domain_hash: u256,
    space: ContractAddress,
    author: EthAddress,
    metadata_uri: Span<felt252>,
    execution_strategy: @Strategy,
    user_proposal_validation_params: Span<felt252>,
    salt: u256
) -> u256 {
    let encoded_data = array![
        u256 { low: PROPOSE_TYPEHASH_LOW, high: PROPOSE_TYPEHASH_HIGH },
        get_contract_address().into(),
        space.into(),
        author.into(),
        metadata_uri.keccak_struct_hash(),
        execution_strategy.keccak_struct_hash(),
        user_proposal_validation_params.keccak_struct_hash(),
        salt
    ];
    let message_hash = keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse();
    hash_typed_data(domain_hash, message_hash)
}

fn get_vote_digest(
    domain_hash: u256,
    space: ContractAddress,
    voter: EthAddress,
    proposal_id: u256,
    choice: Choice,
    user_voting_strategies: Span<IndexedStrategy>,
    metadata_uri: Span<felt252>,
) -> u256 {
    let encoded_data = array![
        u256 { low: VOTE_TYPEHASH_LOW, high: VOTE_TYPEHASH_HIGH },
        get_contract_address().into(),
        space.into(),
        voter.into(),
        proposal_id,
        choice.into(),
        user_voting_strategies.keccak_struct_hash(),
        metadata_uri.keccak_struct_hash()
    ];
    let message_hash = keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse();
    hash_typed_data(domain_hash, message_hash)
}

fn get_update_proposal_digest(
    domain_hash: u256,
    space: ContractAddress,
    author: EthAddress,
    proposal_id: u256,
    execution_strategy: @Strategy,
    metadata_uri: Span<felt252>,
    salt: u256
) -> u256 {
    let encoded_data = array![
        u256 { low: UPDATE_PROPOSAL_TYPEHASH_LOW, high: UPDATE_PROPOSAL_TYPEHASH_HIGH },
        get_contract_address().into(),
        space.into(),
        author.into(),
        proposal_id,
        execution_strategy.keccak_struct_hash(),
        metadata_uri.keccak_struct_hash(),
        salt
    ];
    let message_hash = keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse();
    hash_typed_data(domain_hash, message_hash)
}

fn get_domain_hash() -> u256 {
    // The ethers typed data encoder is not compatible with a Starknet address as the `verifyingContract`
    // therefore we cannot use the `verifyingContract` field in the domain separator, instead we add the 
    //  verifying contract address to the message itself.
    let encoded_data = array![
        u256 { low: DOMAIN_TYPEHASH_LOW, high: DOMAIN_TYPEHASH_HIGH },
        Felt252IntoU256::into(get_tx_info().unbox().chain_id)
    ];
    keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse()
}

fn hash_typed_data(domain_hash: u256, message_hash: u256) -> u256 {
    let encoded_data = _add_prefix_array(array![domain_hash, message_hash], ETHEREUM_PREFIX);
    let (mut u64_arr, overflow) = into_le_u64_array(encoded_data);
    keccak::cairo_keccak(ref u64_arr, overflow, 2).byte_reverse()
}

// Prefixes a 16 bit prefix to an array of 256 bit values.
fn _add_prefix_array(input: Array<u256>, mut prefix: u128) -> Array<u256> {
    let mut out = ArrayTrait::<u256>::new();
    let mut input = input;
    loop {
        match input.pop_front() {
            Option::Some(num) => {
                let (w1, high_carry) = _add_prefix_u128(num.high, prefix);
                let (w0, low_carry) = _add_prefix_u128(num.low, high_carry);
                out.append(u256 { low: w0, high: w1 });
                prefix = low_carry;
            },
            Option::None(_) => {
                // left shift so that the prefix is in the high bits
                out
                    .append(
                        u256 { high: prefix * 0x10000000000000000000000000000_u128, low: 0_u128 }
                    );
                break ();
            }
        };
    };
    out
}


// Adds a 16 bit prefix to a 128 bit input, returning the result and a carry.
fn _add_prefix_u128(input: u128, prefix: u128) -> (u128, u128) {
    let with_prefix = u256 { low: input, high: 0_u128 } + u256 { low: 0_u128, high: prefix };
    let carry = with_prefix & 0xffff;
    // Removing the carry and shifting back.
    let out = (with_prefix - carry) / 0x10000;
    (out.low, carry.low)
}
