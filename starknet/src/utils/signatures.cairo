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
    UPDATE_PROPOSAL_TYPEHASH_HIGH
};
use sx::utils::math::{pow, pow_u128};
use sx::utils::endian::{into_le_u64_array, ByteReverse};
use sx::utils::keccak::KeccakStructHash;
use sx::utils::into::{ContractAddressIntoU256, EthAddressIntoU256};

use debug::PrintTrait;
#[test]
fn it_works() {
    let result = 2 + 2;
    assert(result == 4, 'result is not 4');
}

fn get_message_and_signature(y_parity: bool) -> (u256, Signature, EthAddress) {
    let msg_hash = 0x7dc67e4b7360d57460a229f90a083b16f583a67ddd067ac7b60ee49a1ea22a76;
    let r = 0xe3add80b7e31ab863e2fe27b9bba781289e1f1662a68a5927afb3b76f7d2873c;
    let s = 0x4c499aa8ff416080b58d97589fa8b6e0da7bfb3aa93eb328d7efde5c8d7bea77;

    let b = 27_u32 % 2 == 1;
    b.print();
    y_parity.print();
    r.print();
    let eth_address = 0x2842c82E20ab600F443646e1BC8550B44a513D82_u256.into();

    (msg_hash, Signature { r, s, y_parity }, eth_address)
}

#[test]
#[available_gas(100000000)]
fn test_verify_eth_signature() {
    let y_parity = false;
    let (msg_hash, signature, eth_address) = get_message_and_signature(:y_parity);
    verify_eth_signature::<Secp256k1Point>(:msg_hash, :signature, :eth_address);
}

// Reverts if the signature was not signed by the author. 
fn verify_propose_sig(
    r: u256,
    s: u256,
    v: u32,
    domain_hash: u256,
    target: ContractAddress,
    author: EthAddress,
    execution_strategy: @Strategy,
    user_proposal_validation_params: Span<felt252>,
    salt: u256,
) {
    let digest: u256 = get_propose_digest(
        domain_hash, target, author, execution_strategy, user_proposal_validation_params, salt
    );
    // TODO: temp flipping y parity bit as I think its wrong
    verify_eth_signature::<Secp256k1Point>(digest, signature_from_vrs(v + 1, r, s), author);
}

fn verify_vote_sig(
    r: u256,
    s: u256,
    v: u256,
    domain_hash: u256,
    target: ContractAddress,
    voter: EthAddress,
    proposal_id: u256,
    choice: Choice,
    user_voting_strategies: Span<IndexedStrategy>
) {
    let digest: u256 = get_vote_digest(
        domain_hash, target, voter, proposal_id, choice, user_voting_strategies
    );
// TODO: Actually verify the signature when it gets added
// verify_eth_signature(digest, signature_from_vrs(v, r, s), voter);
}

fn verify_update_proposal_sig(
    r: u256,
    s: u256,
    v: u256,
    domain_hash: u256,
    target: ContractAddress,
    author: EthAddress,
    proposal_id: u256,
    execution_strategy: @Strategy,
    salt: u256
) {
    let digest: u256 = get_update_proposal_digest(
        domain_hash, target, author, proposal_id, execution_strategy, salt
    );
// TODO: Actually verify the signature when it gets added
// secp256k1::verify_eth_signature(digest, r, s, v, author);
}

fn get_propose_digest(
    domain_hash: u256,
    space: ContractAddress,
    author: EthAddress,
    execution_strategy: @Strategy,
    user_proposal_validation_params: Span<felt252>,
    salt: u256
) -> u256 {
    let mut encoded_data = ArrayTrait::<u256>::new();
    encoded_data.append(u256 { low: PROPOSE_TYPEHASH_LOW, high: PROPOSE_TYPEHASH_HIGH });
    encoded_data.append(get_contract_address().into());
    encoded_data.append(space.into());
    encoded_data.append(author.into());
    encoded_data.append(execution_strategy.keccak_struct_hash());
    encoded_data.append(user_proposal_validation_params.keccak_struct_hash());
    encoded_data.append(salt);
    let message_hash = keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse();
    hash_typed_data(domain_hash, message_hash)
}

fn get_vote_digest(
    domain_hash: u256,
    space: ContractAddress,
    voter: EthAddress,
    proposal_id: u256,
    choice: Choice,
    user_voting_strategies: Span<IndexedStrategy>
) -> u256 {
    let mut encoded_data = ArrayTrait::<u256>::new();
    encoded_data.append(u256 { low: VOTE_TYPEHASH_LOW, high: VOTE_TYPEHASH_HIGH });
    encoded_data.append(get_contract_address().into());
    encoded_data.append(space.into());
    encoded_data.append(voter.into());
    encoded_data.append(proposal_id);
    encoded_data.append(choice.into());
    encoded_data.append(user_voting_strategies.keccak_struct_hash());
    let message_hash = keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse();
    hash_typed_data(domain_hash, message_hash)
}

fn get_update_proposal_digest(
    domain_hash: u256,
    space: ContractAddress,
    author: EthAddress,
    proposal_id: u256,
    execution_strategy: @Strategy,
    salt: u256
) -> u256 {
    let mut encoded_data = ArrayTrait::<u256>::new();
    encoded_data
        .append(u256 { low: UPDATE_PROPOSAL_TYPEHASH_LOW, high: UPDATE_PROPOSAL_TYPEHASH_HIGH });
    encoded_data.append(get_contract_address().into());
    encoded_data.append(space.into());
    encoded_data.append(author.into());
    encoded_data.append(proposal_id);
    encoded_data.append(execution_strategy.keccak_struct_hash());
    encoded_data.append(salt);
    let message_hash = keccak::keccak_u256s_be_inputs(encoded_data.span());
    hash_typed_data(domain_hash, message_hash)
}

fn get_domain_hash() -> u256 {
    let mut encoded_data = ArrayTrait::<u256>::new();
    encoded_data.append(u256 { low: DOMAIN_TYPEHASH_LOW, high: DOMAIN_TYPEHASH_HIGH });
    encoded_data.append(get_tx_info().unbox().chain_id.into());
    keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse()
}

fn hash_typed_data(domain_hash: u256, message_hash: u256) -> u256 {
    let mut encoded_data = ArrayTrait::<u256>::new();
    encoded_data.append(domain_hash);
    encoded_data.append(message_hash);
    let encoded_data = _add_prefix_array(encoded_data, ETHEREUM_PREFIX);
    let (mut u64_arr, overflow) = into_le_u64_array(encoded_data);
    keccak::cairo_keccak(ref u64_arr, overflow, 2).byte_reverse()
}

// Prefixes a 16 bit prefix to an array of 256 bit values.
fn _add_prefix_array(input: Array<u256>, mut prefix: u128) -> Array<u256> {
    let mut out = ArrayTrait::<u256>::new();
    let mut i = 0_usize;
    loop {
        if i >= input.len() {
            // left shift so that the prefix is in the high bits
            // let prefix_u256 = u256 { low: 0_128, high: prefix };
            // let shifted_prefix = prefix_u256 * pow(u256 { low: 2_u128, high: 0_u128 }, 112_u8);
            let shifted_prefix = prefix * pow_u128(2_u128, 112_u8);
            out.append(u256 { high: shifted_prefix, low: 0_u128 });
            break ();
        }
        let num = *input.at(i);
        let (w1, high_carry) = _add_prefix_u128(num.high, prefix);
        let (w0, low_carry) = _add_prefix_u128(num.low, high_carry);

        out.append(u256 { low: w0, high: w1 });
        prefix = low_carry;
        i += 1;
    };
    out
}

// prefixes a 16 bit prefix to a 128 bit input, returning the result and a carry if it overflows 128 bits
fn _add_prefix_u128(input: u128, prefix: u128) -> (u128, u128) {
    let prefix_u256 = u256 { low: prefix, high: 0_u128 };
    let shifted_prefix = prefix_u256 * pow(u256 { low: 2_u128, high: 0_u128 }, 128_u8);
    let with_prefix = u256 { low: input, high: 0_u128 } + shifted_prefix;
    let overflow_mask = pow(u256 { low: 2_u128, high: 0_u128 }, 16_u8) - u256 {
        low: 1_u128, high: 0_u128
    };
    let carry = with_prefix & overflow_mask;
    // Removing the carry and shifting back. The result fits in 128 bits.
    let out = ((with_prefix - carry) / pow(u256 { low: 2_u128, high: 0_u128 }, 16_u8));
    (out.low, carry.low)
}
