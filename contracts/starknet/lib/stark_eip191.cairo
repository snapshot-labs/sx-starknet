%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.starknet.common.syscalls import get_contract_address
from contracts.starknet.lib.felt_utils import FeltUtils
from contracts.starknet.lib.array_utils import ArrayUtils

//
// @title StarkNet EIP191 Library
// @author SnapshotLabs
// @notice A library for verifying StarkNet EIP191 signatures on typed data required for Snapshot X
// @dev Refer to the official EIP for more information: https://eips.ethereum.org/EIPS/eip-191
//

// NOTE: We will need to update chain ID for prod
// { name: 'snapshot-x', version: '1', chainId: '0x534e5f474f45524c49'} (chainID: SN_GOERLI)
const DOMAIN_HASH = 0x7b887e96718721a64b601a4873454d4a9e26a4b798d660c8d6b96d2045c8404;

const STARKNET_MESSAGE = 0x537461726b4e6574204d657373616765;

// getSelectorFromName("Propose(space:felt,author:felt,metadata_uri:felt*,executor:felt,execution_hash:felt,strategies_hash:felt,strategies_params_hash:felt,salt:felt)")
const PROPOSAL_TYPE_HASH = 0x2092032d2957beaa83248292f326648fd2ad923d97f59c75296e41d924c5355;

// getSelectorFromName("Vote(space:felt,voter:felt,proposal:felt,choice:felt,strategies_hash:felt,strategies_params_hash:felt,salt:felt)")
const VOTE_TYPE_HASH = 0x31236321e2e03bd76ca3b07ff9544b3d50aa3e677b473a2850a894dcd983781;

// getSelectorFromName("RevokeSessionKey(salt:felt)")
const REVOKE_SESSION_KEY_TYPE_HASH = 0x31F0BF4E2BBD12ECBA02E325F0EA3231350A638FC633AF8EBF244F50663ACE8;

// @dev Signature salts store
@storage_var
func StarkEIP191_salts(user: felt, salt: felt) -> (already_used: felt) {
}

namespace StarkEIP191 {
    // @dev Asserts that a signature to create a proposal is valid
    // @param r Signature parameter
    // @param s Signature parameter
    // @param salt Signature salt
    // @param target Address of the space contract where the user is creating a proposal
    // @param calldata Propose calldata
    // @public_key The StarkNet key that was used to generate the signature
    func verify_propose_sig{
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
        ecdsa_ptr: SignatureBuiltin*,
    }(
        r: felt,
        s: felt,
        salt: felt,
        target: felt,
        calldata_len: felt,
        calldata: felt*,
        public_key: felt,
    ) {
        alloc_locals;

        let proposer_address = calldata[0];

        let (authenticator) = get_contract_address();

        // Ensure proposer has not already used this salt in a previous action
        let (already_used) = StarkEIP191_salts.read(proposer_address, salt);

        with_attr error_message("StarkEIP191: Salt already used") {
            assert already_used = 0;
        }

        // Metadata URI
        let metadata_uri_string_len = calldata[1];
        let metadata_uri_len = calldata[2];
        let metadata_uri: felt* = &calldata[3];
        let (metadata_uri_hash) = ArrayUtils.hash(metadata_uri_len, metadata_uri);

        // Executor
        let executor = calldata[3 + metadata_uri_len];
        let (executor_u256) = FeltUtils.felt_to_uint256(executor);

        // Used voting strategies
        let used_voting_strats_len = calldata[4 + metadata_uri_len];
        let used_voting_strats = &calldata[5 + metadata_uri_len];
        let (used_voting_strategies_hash) = ArrayUtils.hash(
            used_voting_strats_len, used_voting_strats
        );

        // User voting strategy params flat
        let user_voting_strat_params_flat_len = calldata[5 + metadata_uri_len + used_voting_strats_len];
        let user_voting_strat_params_flat = &calldata[6 + metadata_uri_len + used_voting_strats_len];
        let (user_voting_strategy_params_flat_hash) = ArrayUtils.hash(
            user_voting_strat_params_flat_len, user_voting_strat_params_flat
        );

        // Execution hash
        let execution_params_len = calldata[6 + metadata_uri_len + used_voting_strats_len + user_voting_strat_params_flat_len];
        let execution_params_ptr: felt* = &calldata[7 + metadata_uri_len + used_voting_strats_len + user_voting_strat_params_flat_len];
        let (execution_hash) = ArrayUtils.hash(execution_params_len, execution_params_ptr);

        let (structure: felt*) = alloc();

        assert structure[0] = PROPOSAL_TYPE_HASH;
        assert structure[1] = target;
        assert structure[2] = proposer_address;
        assert structure[3] = metadata_uri_hash;
        assert structure[4] = executor;
        assert structure[5] = execution_hash;
        assert structure[6] = used_voting_strategies_hash;
        assert structure[7] = user_voting_strategy_params_flat_hash;
        assert structure[8] = salt;

        let (hash_struct) = ArrayUtils.hash(9, structure);

        let (message: felt*) = alloc();

        assert message[0] = STARKNET_MESSAGE;
        assert message[1] = DOMAIN_HASH;
        assert message[2] = authenticator;
        assert message[3] = hash_struct;

        let (message_hash) = ArrayUtils.hash(4, message);

        verify_ecdsa_signature(message_hash, public_key, r, s);

        StarkEIP191_salts.write(proposer_address, salt, 1);

        return ();
    }

    // @dev Asserts that a signature to cast a vote is valid
    // @param r Signature parameter
    // @param s Signature parameter
    // @param salt Signature salt
    // @param target Address of the space contract where the user is casting a vote
    // @param calldata Vote calldata
    // @public_key The StarkNet key that was used to generate the signature
    func verify_vote_sig{
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
        ecdsa_ptr: SignatureBuiltin*,
    }(
        r: felt,
        s: felt,
        salt: felt,
        target: felt,
        calldata_len: felt,
        calldata: felt*,
        public_key: felt,
    ) {
        alloc_locals;

        let voter_address = calldata[0];

        let (authenticator) = get_contract_address();

        // Ensure voter has not already used this salt in a previous action
        let (already_used) = StarkEIP191_salts.read(voter_address, salt);

        with_attr error_message("StarkEIP191: Salt already used") {
            assert already_used = 0;
        }

        let proposal_id = calldata[1];
        let choice = calldata[2];

        let used_voting_strategies_len = calldata[3];
        let used_voting_strategies = &calldata[4];
        let (used_voting_strategies_hash) = ArrayUtils.hash(
            used_voting_strategies_len, used_voting_strategies
        );

        let user_voting_strategy_params_flat_len = calldata[4 + used_voting_strategies_len];
        let user_voting_strategy_params_flat = &calldata[5 + used_voting_strategies_len];
        let (user_voting_strategy_params_flat_hash) = ArrayUtils.hash(
            user_voting_strategy_params_flat_len, user_voting_strategy_params_flat
        );

        // Now construct the data hash (hashStruct)
        let (structure: felt*) = alloc();
        assert structure[0] = VOTE_TYPE_HASH;
        assert structure[1] = target;
        assert structure[2] = voter_address;
        assert structure[3] = proposal_id;
        assert structure[4] = choice;
        assert structure[5] = used_voting_strategies_hash;
        assert structure[6] = user_voting_strategy_params_flat_hash;
        assert structure[7] = salt;

        let (hash_struct) = ArrayUtils.hash(8, structure);

        let (message: felt*) = alloc();

        assert message[0] = STARKNET_MESSAGE;
        assert message[1] = DOMAIN_HASH;
        assert message[2] = authenticator;
        assert message[3] = hash_struct;

        let (message_hash) = ArrayUtils.hash(4, message);

        verify_ecdsa_signature(message_hash, public_key, r, s);

        StarkEIP191_salts.write(voter_address, salt, 1);

        return ();
    }

    // @dev Asserts that a signature to revoke a session key is valid
    // @param r Signature parameter
    // @param s Signature parameter
    // @param salt Signature salt
    // @public_key The StarkNet key that was used to generate the signature
    func verify_session_key_revoke_sig{
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
        ecdsa_ptr: SignatureBuiltin*,
    }(r: felt, s: felt, salt: felt, public_key: felt) {
        alloc_locals;

        let (authenticator) = get_contract_address();

        // Ensure voter has not already used this salt in a previous action
        let (already_used) = StarkEIP191_salts.read(public_key, salt);
        with_attr error_message("StarkEIP191: Salt already used") {
            assert already_used = 0;
        }

        // Now construct the data hash (hashStruct)
        let (structure: felt*) = alloc();
        assert structure[0] = REVOKE_SESSION_KEY_TYPE_HASH;
        assert structure[1] = salt;

        let (hash_struct) = ArrayUtils.hash(2, structure);

        let (message: felt*) = alloc();

        assert message[0] = STARKNET_MESSAGE;
        assert message[1] = DOMAIN_HASH;
        assert message[2] = authenticator;
        assert message[3] = hash_struct;

        let (message_hash) = ArrayUtils.hash(4, message);

        verify_ecdsa_signature(message_hash, public_key, r, s);

        StarkEIP191_salts.write(public_key, salt, 1);

        return ();
    }
}
