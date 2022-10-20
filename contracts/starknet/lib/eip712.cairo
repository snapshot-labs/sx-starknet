// SPDX-License-Identifier: MIT

%lang starknet

from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.cairo_keccak.keccak import (
    keccak_uint256s_bigend,
    keccak_add_uint256s,
    keccak_bigend,
    finalize_keccak,
)
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_eq,
    uint256_mul,
    uint256_unsigned_div_rem,
)

from contracts.starknet.lib.felt_utils import FeltUtils
from contracts.starknet.lib.array_utils import ArrayUtils
from contracts.starknet.lib.uint256_utils import Uint256Utils

//
// @title EIP712 Library
// @author SnapshotLabs
// @notice A library for verifying Ethereum EIP712 signatures on typed data required for Snapshot X
// @dev Refer to the official EIP for more information: https://eips.ethereum.org/EIPS/eip-712
//

const ETHEREUM_PREFIX = 0x1901;

// Domain Separator: (Goerli chain id)
// name: 'snapshot-x',
// version: '1'
// chainId: '5'
const DOMAIN_HASH_HIGH = 0x8aba6bf30572474cf5acb579ce4c27aa;
const DOMAIN_HASH_LOW = 0x01d7dbffc7a8de3d601367229ba8a687;

// keccak256("Propose(bytes32 authenticator,bytes32 space,address author,string metadata_uri,bytes32 executor,bytes32 execution_hash,bytes32 strategies_hash,bytes32 strategies_params_hash,uint256 salt)")
const PROPOSAL_TYPE_HASH_HIGH = 0x53ca73f14c436dd8e4088b71987f1dad;
const PROPOSAL_TYPE_HASH_LOW = 0x4187b44b32f86ed0ba765a166eaa687e;

// keccak256("Vote(bytes32 authenticator,bytes32 space,address voter,uint256 proposal,uint256 choice,bytes32 strategies_hash,bytes32 strategies_params_hash,uint256 salt)")
const VOTE_TYPE_HASH_HIGH = 0x7c25de9274f16730816515e2132f9775;
const VOTE_TYPE_HASH_LOW = 0x17f55b8568b810cc267dc2999edce64a;

// keccak256("SessionKey(address address,bytes32 sessionPublicKey,uint256 sessionDuration,uint256 salt)")
const SESSION_KEY_INIT_TYPE_HASH_HIGH = 0x53f1294cb551b4ff97c8fd4caefa8ec6;
const SESSION_KEY_INIT_TYPE_HASH_LOW = 0xaa9d835345c95b1a435ddff5ae910083;

// keccak256("RevokeSessionKey(bytes32 sessionPublicKey,uint256 salt)")
const SESSION_KEY_REVOKE_TYPE_HASH_HIGH = 0x0a5ba214c2c419ff474ecb96dc30103d;
const SESSION_KEY_REVOKE_TYPE_HASH_LOW = 0x8166de3d410abc781e23aae247360fa9;

// @dev Signature salts store
@storage_var
func EIP712_salts(eth_address: felt, salt: Uint256) -> (already_used: felt) {
}

namespace EIP712 {
    // @dev Asserts that a signature to cast a vote is valid
    // @param r Signature parameter
    // @param s Signature parameter
    // @param v Signature parameter
    // @param salt Signature salt
    // @param target Address of the space contract where the user is casting a vote
    // @param calldata Vote calldata
    func verify_vote_sig{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        r: Uint256,
        s: Uint256,
        v: felt,
        salt: Uint256,
        target: felt,
        calldata_len: felt,
        calldata: felt*,
    ) {
        alloc_locals;

        Uint256Utils.assert_valid_uint256(r);
        Uint256Utils.assert_valid_uint256(s);
        Uint256Utils.assert_valid_uint256(salt);

        let voter_address = calldata[0];
        let (authenticator_address) = get_contract_address();
        let (auth_address_u256) = FeltUtils.felt_to_uint256(authenticator_address);

        // Ensure voter has not already used this salt in a previous action
        let (already_used) = EIP712_salts.read(voter_address, salt);
        with_attr error_message("EIP712: Salt already used") {
            assert already_used = 0;
        }

        let (space) = FeltUtils.felt_to_uint256(target);

        let (voter_address_u256) = FeltUtils.felt_to_uint256(voter_address);

        let (proposal_id) = FeltUtils.felt_to_uint256(calldata[1]);
        let (choice) = FeltUtils.felt_to_uint256(calldata[2]);

        let used_voting_strategies_len = calldata[3];
        let used_voting_strategies = &calldata[4];
        let (used_voting_strategies_hash) = _get_padded_hash(
            used_voting_strategies_len, used_voting_strategies
        );

        let user_voting_strategy_params_flat_len = calldata[4 + used_voting_strategies_len];
        let user_voting_strategy_params_flat = &calldata[5 + used_voting_strategies_len];
        let (user_voting_strategy_params_flat_hash) = _get_padded_hash(
            user_voting_strategy_params_flat_len, user_voting_strategy_params_flat
        );

        // Now construct the data hash (hashStruct)
        let (data: Uint256*) = alloc();
        assert data[0] = Uint256(VOTE_TYPE_HASH_LOW, VOTE_TYPE_HASH_HIGH);
        assert data[1] = auth_address_u256;
        assert data[2] = space;
        assert data[3] = voter_address_u256;
        assert data[4] = proposal_id;
        assert data[5] = choice;
        assert data[6] = used_voting_strategies_hash;
        assert data[7] = user_voting_strategy_params_flat_hash;
        assert data[8] = salt;

        let (local keccak_ptr: felt*) = alloc();
        let keccak_ptr_start = keccak_ptr;

        let (hash_struct) = _get_keccak_hash{keccak_ptr=keccak_ptr}(9, data);

        // Prepare the encoded data
        let (prepared_encoded: Uint256*) = alloc();
        assert prepared_encoded[0] = Uint256(DOMAIN_HASH_LOW, DOMAIN_HASH_HIGH);
        assert prepared_encoded[1] = hash_struct;

        // Prepend the ethereum prefix
        let (encoded_data: Uint256*) = alloc();
        _prepend_prefix_2bytes(ETHEREUM_PREFIX, encoded_data, 2, prepared_encoded);

        // Now go from Uint256s to Uint64s (required in order to call `keccak`)
        let (signable_bytes) = alloc();
        let signable_bytes_start = signable_bytes;
        keccak_add_uint256s{inputs=signable_bytes}(n_elements=3, elements=encoded_data, bigend=1);

        // Compute the hash
        let (hash) = keccak_bigend{keccak_ptr=keccak_ptr}(
            inputs=signable_bytes_start, n_bytes=2 * 32 + 2
        );

        // `v` is supposed to be `yParity` and not the `v` usually used in the Ethereum world (pre-EIP155).
        // We substract `27` because `v` = `{0, 1} + 27`
        verify_eth_signature_uint256{keccak_ptr=keccak_ptr}(hash, r, s, v - 27, voter_address);

        // Verify that all the previous keccaks are correct
        finalize_keccak(keccak_ptr_start, keccak_ptr);

        // Write the salt to prevent replay attack
        EIP712_salts.write(voter_address, salt, 1);
        return ();
    }

    // @dev Asserts that a signature to create a proposal is valid
    // @param r Signature parameter
    // @param s Signature parameter
    // @param v Signature parameter
    // @param salt Signature salt
    // @param target Address of the space contract where the user is creating a proposal
    // @param calldata Propose calldata
    func verify_propose_sig{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        r: Uint256,
        s: Uint256,
        v: felt,
        salt: Uint256,
        target: felt,
        calldata_len: felt,
        calldata: felt*,
    ) {
        alloc_locals;

        Uint256Utils.assert_valid_uint256(r);
        Uint256Utils.assert_valid_uint256(s);
        Uint256Utils.assert_valid_uint256(salt);

        // Proposer address should be located in calldata[0]
        let proposer_address = calldata[0];

        let (authenticator_address) = get_contract_address();
        let (auth_address_u256) = FeltUtils.felt_to_uint256(authenticator_address);

        // Ensure proposer has not already used this salt in a previous action
        let (already_used) = EIP712_salts.read(proposer_address, salt);
        with_attr error_message("EIP712: Salt already used") {
            assert already_used = 0;
        }

        let (local keccak_ptr: felt*) = alloc();
        let keccak_ptr_start = keccak_ptr;

        // We don't need to pad because calling `.address` with starknet.js
        // already left pads the address with 0s
        let (space) = FeltUtils.felt_to_uint256(target);

        // Proposer address
        let (proposer_address_u256) = FeltUtils.felt_to_uint256(proposer_address);

        // Metadata URI
        let metadata_uri_string_len = calldata[1];
        let metadata_uri_len = calldata[2];
        let metadata_uri: felt* = &calldata[3];
        let (metadata_uri_hash) = _keccak_ints_sequence{keccak_ptr=keccak_ptr}(
            metadata_uri_string_len, metadata_uri_len, metadata_uri
        );

        // Execution Strategy
        let execution_strategy = calldata[3 + metadata_uri_len];
        let (execution_strategy_u256) = FeltUtils.felt_to_uint256(execution_strategy);

        // Used voting strategies
        let used_voting_strats_len = calldata[4 + metadata_uri_len];
        let used_voting_strats = &calldata[5 + metadata_uri_len];
        let (used_voting_strategies_hash) = _get_padded_hash(
            used_voting_strats_len, used_voting_strats
        );

        // User voting strategy params flat
        let user_voting_strat_params_flat_len = calldata[5 + metadata_uri_len + used_voting_strats_len];
        let user_voting_strat_params_flat = &calldata[6 + metadata_uri_len + used_voting_strats_len];
        let (user_voting_strategy_params_flat_hash) = _get_padded_hash(
            user_voting_strat_params_flat_len, user_voting_strat_params_flat
        );

        // Execution hash
        let execution_params_len = calldata[6 + metadata_uri_len + used_voting_strats_len + user_voting_strat_params_flat_len];
        let execution_params_ptr: felt* = &calldata[7 + metadata_uri_len + used_voting_strats_len + user_voting_strat_params_flat_len];
        let (execution_hash) = _get_padded_hash(execution_params_len, execution_params_ptr);

        // Now construct the data hash (hashStruct)
        let (data: Uint256*) = alloc();

        assert data[0] = Uint256(PROPOSAL_TYPE_HASH_LOW, PROPOSAL_TYPE_HASH_HIGH);
        assert data[1] = auth_address_u256;
        assert data[2] = space;
        assert data[3] = proposer_address_u256;
        assert data[4] = metadata_uri_hash;
        assert data[5] = execution_strategy_u256;
        assert data[6] = execution_hash;
        assert data[7] = used_voting_strategies_hash;
        assert data[8] = user_voting_strategy_params_flat_hash;
        assert data[9] = salt;

        let (hash_struct) = _get_keccak_hash{keccak_ptr=keccak_ptr}(10, data);

        // Prepare the encoded data
        let (prepared_encoded: Uint256*) = alloc();
        assert prepared_encoded[0] = Uint256(DOMAIN_HASH_LOW, DOMAIN_HASH_HIGH);
        assert prepared_encoded[1] = hash_struct;

        // Prepend the ethereum prefix
        let (encoded_data: Uint256*) = alloc();
        _prepend_prefix_2bytes(ETHEREUM_PREFIX, encoded_data, 2, prepared_encoded);

        // Now go from Uint256s to Uint64s (required in order to call `keccak`)
        let (signable_bytes) = alloc();
        let signable_bytes_start = signable_bytes;
        keccak_add_uint256s{inputs=signable_bytes}(n_elements=3, elements=encoded_data, bigend=1);

        // Compute the hash
        let (hash) = keccak_bigend{keccak_ptr=keccak_ptr}(
            inputs=signable_bytes_start, n_bytes=2 * 32 + 2
        );

        // `v` is supposed to be `yParity` and not the `v` usually used in the Ethereum world (pre-EIP155).
        // We substract `27` because `v` = `{0, 1} + 27`
        verify_eth_signature_uint256{keccak_ptr=keccak_ptr}(hash, r, s, v - 27, proposer_address);

        // Verify that all the previous keccaks are correct
        finalize_keccak(keccak_ptr_start, keccak_ptr);

        // Write the salt to prevent replay attack
        EIP712_salts.write(proposer_address, salt, 1);

        return ();
    }

    // @dev Asserts that a signature to authorize a session key is valid
    // @param r Signature parameter
    // @param s Signature parameter
    // @param v Signature parameter
    // @param salt Signature salt
    // @param eth_address Owner's Ethereum Address that was used to create the signature
    // @param session_public_key The StarkNet session public key that should be registered
    // @param session_duration The number of seconds that the session key is valid
    func verify_session_key_auth_sig{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(
        r: Uint256,
        s: Uint256,
        v: felt,
        salt: Uint256,
        eth_address: felt,
        session_public_key: felt,
        session_duration: felt,
    ) -> () {
        alloc_locals;

        Uint256Utils.assert_valid_uint256(r);
        Uint256Utils.assert_valid_uint256(s);
        Uint256Utils.assert_valid_uint256(salt);

        // Ensure user has not already used this salt in a previous action
        let (already_used) = EIP712_salts.read(eth_address, salt);
        with_attr error_message("EIP712: Salt already used") {
            assert already_used = 0;
        }

        // Encode data
        let (eth_address_u256) = FeltUtils.felt_to_uint256(eth_address);

        let (session_public_key_u256) = FeltUtils.felt_to_uint256(session_public_key);
        let (padded_session_public_key) = _pad_right(session_public_key_u256);

        let (session_duration_u256) = FeltUtils.felt_to_uint256(session_duration);

        // Now construct the data array
        let (data: Uint256*) = alloc();
        assert data[0] = Uint256(SESSION_KEY_INIT_TYPE_HASH_LOW, SESSION_KEY_INIT_TYPE_HASH_HIGH);
        assert data[1] = eth_address_u256;
        assert data[2] = padded_session_public_key;
        assert data[3] = session_duration_u256;
        assert data[4] = salt;

        // Hash the data array
        let (local keccak_ptr: felt*) = alloc();
        let keccak_ptr_start = keccak_ptr;
        let (hash_struct) = _get_keccak_hash{keccak_ptr=keccak_ptr}(5, data);

        // Prepend the domain separator hash
        let (prepared_encoded: Uint256*) = alloc();
        assert prepared_encoded[0] = Uint256(DOMAIN_HASH_LOW, DOMAIN_HASH_HIGH);
        assert prepared_encoded[1] = hash_struct;

        // Prepend the ethereum prefix
        let (encoded_data: Uint256*) = alloc();
        _prepend_prefix_2bytes(ETHEREUM_PREFIX, encoded_data, 2, prepared_encoded);

        // Now go from Uint256s to Uint64s (required for the cairo keccak implementation)
        let (signable_bytes) = alloc();
        let signable_bytes_start = signable_bytes;
        keccak_add_uint256s{inputs=signable_bytes}(n_elements=3, elements=encoded_data, bigend=1);

        // Compute the hash
        let (msg_hash) = keccak_bigend{keccak_ptr=keccak_ptr}(
            inputs=signable_bytes_start, n_bytes=2 * 32 + 2
        );

        // `v` is supposed to be `yParity` and not the `v` usually used in the Ethereum world (pre-EIP155).
        // We substract `27` because `v` = `{0, 1} + 27`
        verify_eth_signature_uint256{keccak_ptr=keccak_ptr}(msg_hash, r, s, v - 27, eth_address);

        // Verify that all the previous keccaks are correct
        finalize_keccak(keccak_ptr_start, keccak_ptr);

        // Write the salt to prevent replay attack
        EIP712_salts.write(eth_address, salt, 1);

        return ();
    }

    // @dev Asserts that a signature to revoke a session key is valid
    // @param r Signature parameter
    // @param s Signature parameter
    // @param v Signature parameter
    // @param salt Signature salt
    // @param eth_address Owner's Ethereum Address that was used to create the signature
    // @param session_public_key The StarkNet session public key that should be revoked
    func verify_session_key_revoke_sig{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(
        r: Uint256, s: Uint256, v: felt, salt: Uint256, eth_address: felt, session_public_key: felt
    ) -> () {
        alloc_locals;

        Uint256Utils.assert_valid_uint256(r);
        Uint256Utils.assert_valid_uint256(s);
        Uint256Utils.assert_valid_uint256(salt);

        // Ensure user has not already used this salt in a previous action
        let (already_used) = EIP712_salts.read(eth_address, salt);
        with_attr error_message("EIP712: Salt already used") {
            assert already_used = 0;
        }

        // Encode data
        let (session_public_key_u256) = FeltUtils.felt_to_uint256(session_public_key);
        let (padded_session_public_key) = _pad_right(session_public_key_u256);

        // Now construct the data array
        let (data: Uint256*) = alloc();
        assert data[0] = Uint256(SESSION_KEY_REVOKE_TYPE_HASH_LOW, SESSION_KEY_REVOKE_TYPE_HASH_HIGH);
        assert data[1] = padded_session_public_key;
        assert data[2] = salt;

        // Hash the data array
        let (local keccak_ptr: felt*) = alloc();
        let keccak_ptr_start = keccak_ptr;
        let (hash_struct) = _get_keccak_hash{keccak_ptr=keccak_ptr}(3, data);

        // Prepend the domain separator hash
        let (prepared_encoded: Uint256*) = alloc();
        assert prepared_encoded[0] = Uint256(DOMAIN_HASH_LOW, DOMAIN_HASH_HIGH);
        assert prepared_encoded[1] = hash_struct;

        // Prepend the ethereum prefix
        let (encoded_data: Uint256*) = alloc();
        _prepend_prefix_2bytes(ETHEREUM_PREFIX, encoded_data, 2, prepared_encoded);

        // Now go from Uint256s to Uint64s (required for the cairo keccak implementation)
        let (signable_bytes) = alloc();
        let signable_bytes_start = signable_bytes;
        keccak_add_uint256s{inputs=signable_bytes}(n_elements=3, elements=encoded_data, bigend=1);

        // Compute the hash
        let (msg_hash) = keccak_bigend{keccak_ptr=keccak_ptr}(
            inputs=signable_bytes_start, n_bytes=2 * 32 + 2
        );

        // `v` is supposed to be `yParity` and not the `v` usually used in the Ethereum world (pre-EIP155).
        // We substract `27` because `v` = `{0, 1} + 27`
        verify_eth_signature_uint256{keccak_ptr=keccak_ptr}(msg_hash, r, s, v - 27, eth_address);

        // Verify that all the previous keccaks are correct
        finalize_keccak(keccak_ptr_start, keccak_ptr);

        // Write the salt to prevent replay attack
        EIP712_salts.write(eth_address, salt, 1);

        return ();
    }
}

//
//  Private Functions
//

// Adds a 2 bytes (16 bits) `prefix` to a 16 bytes (128 bits) `value`.
func _add_prefix128{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(value: felt, prefix: felt) -> (
    result: felt, carry: felt
) {
    // Shift the prefix by 128 bits
    let shifted_prefix = prefix * 2 ** 128;
    // `with_prefix` is now 18 bytes long
    let with_prefix = shifted_prefix + value;
    // Create 2 bytes mask
    let overflow_mask = 2 ** 16 - 1;
    // Extract the last two bytes of `with_prefix`
    let (carry) = bitwise_and(with_prefix, overflow_mask);
    // Compute the new number, right shift by 16
    let result = (with_prefix - carry) / 2 ** 16;
    return (result, carry);
}

// Concatenates a 2 bytes long `prefix` and `input` to `output`.
// `input_len` is the number of `Uint256` in `input`.
func _prepend_prefix_2bytes{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    prefix: felt, output: Uint256*, input_len: felt, input: Uint256*
) {
    if (input_len == 0) {
        // Done, simlpy store the prefix in the `.high` part of the last Uint256, and
        // make sure we left shift it by 28 (32 - 4)
        assert output[0] = Uint256(0, prefix * 16 ** 28);
        return ();
    } else {
        let num = input[0];

        let (w1, high_carry) = _add_prefix128(num.high, prefix);
        let (w0, low_carry) = _add_prefix128(num.low, high_carry);

        let res = Uint256(w0, w1);
        assert output[0] = res;

        // Recurse, using the `low_carry` as `prefix`
        _prepend_prefix_2bytes(low_carry, &output[1], input_len - 1, &input[1]);
        return ();
    }
}

// Computes the `keccak256` hash from an array of `Uint256`. Does NOT call `finalize_keccak`,
// so the caller needs to make she calls `finalize_keccak` on the `keccak_ptr` once she's done
// with it.
func _get_keccak_hash{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: felt*}(
    uint256_words_len: felt, uint256_words: Uint256*
) -> (hash: Uint256) {
    let (hash) = keccak_uint256s_bigend{keccak_ptr=keccak_ptr}(uint256_words_len, uint256_words);

    return (hash,);
}

// Returns the number of digits needed to represent `num` in hexadecimal.
// Similar to doing `len(hex(num)[2:])` in Python.
// E.g.:
// - `0x123` will return `3`
// - `0x1` will return `1`
// - `0xa3b1d4` will return `6`
// Notice: Will not work for `0x0` (will return `0` for `0x0` instead of `1`).
func _get_base16_len{range_check_ptr}(num: Uint256) -> (res: felt) {
    let (is_eq) = uint256_eq(num, Uint256(0, 0));
    if (is_eq == 1) {
        return (0,);
    } else {
        // Divide by 16
        let (divided, _) = uint256_unsigned_div_rem(num, Uint256(16, 0));

        let (res_len) = _get_base16_len(divided);
        return (res_len + 1,);
    }
}

// Computes `base ** exp` where `base` and `exp` are both `felts` and returns the result as a `Uint256`.
func _u256_pow{range_check_ptr}(base: felt, exp: felt) -> (res: Uint256) {
    alloc_locals;

    if (exp == 0) {
        // Any number to the power of 0 is 1
        return (Uint256(1, 0),);
    } else {
        // Compute `base ** exp - 1`
        let (recursion) = _u256_pow(base, exp - 1);

        let (uint256_base) = FeltUtils.felt_to_uint256(base);

        // Multiply the result by `base`
        let (res, overflow) = uint256_mul(recursion, uint256_base);

        with_attr error_message("EIP712: Overflow happened") {
            let (no_overflow) = uint256_eq(overflow, Uint256(0, 0));
            assert no_overflow = 1;
        }

        return (res,);
    }
}

// Right pads `num` with `0` to make it 32 bytes long.
// E.g:
// - right_pad(0x1)  -> (0x0100000000000000000000000000000000000000000000000000000000000000)
// - right_pad(0xaa) -> (0xaa00000000000000000000000000000000000000000000000000000000000000)
func _pad_right{range_check_ptr}(num: Uint256) -> (res: Uint256) {
    let (len_base16) = _get_base16_len(num);

    let (_, rem) = unsigned_div_rem(len_base16, 2);
    if (rem == 1) {
        // Odd-length: add one (a byte is two characters long)
        tempvar len_base16 = len_base16 + 1;
    } else {
        tempvar len_base16 = len_base16;
    }

    let base = 16;
    let exp = 64 - len_base16;
    let (power_16) = _u256_pow(base, exp);

    // Left shift
    let (low, high) = uint256_mul(num, power_16);

    with_attr error_message("EIP712: Overflow happened") {
        assert high.low = 0;
        assert high.high = 0;
    }

    return (low,);
}

func _keccak_ints_sequence{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: felt*}(
    nb_bytes: felt, sequence_len: felt, sequence: felt*
) -> (res: Uint256) {
    return keccak_bigend(inputs=sequence, n_bytes=nb_bytes);
}

func _get_padded_hash{range_check_ptr, pedersen_ptr: HashBuiltin*}(
    input_len: felt, input: felt*
) -> (res: Uint256) {
    alloc_locals;

    let (hash) = ArrayUtils.hash(input_len, input);
    let (hash_u256) = FeltUtils.felt_to_uint256(hash);
    let (padded_hash) = _pad_right(hash_u256);

    return (res=padded_hash);
}
