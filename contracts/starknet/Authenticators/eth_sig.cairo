%lang starknet
from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.felt_to_uint256 import felt_to_uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

const PROPOSAL_SELECTOR = 1
const VOTE_SELECTOR = 2

const ETHEREUM_PREFIX = 0x1901

# keccak256("Propose(uint256 nonce,bytes32 space,bytes32 executionHash,string metadataURI)")
# 0xb165e31e54251c4e587d1ab2c6d929b2471c024bf48d00ebc9ca94777b0aa13d
const PROPOSAL_HASH_LOW = 0x471c024bf48d00ebc9ca94777b0aa13d
const PROPOSAL_HASH_HIGH = 0xb165e31e54251c4e587d1ab2c6d929b2

# keccak256("Vote(uint256 nonce,bytes32 space,uint256 proposal,uint256 choice)")
# 0x5a6ef60fd4d9b84327ba5c43cada66cd075ba32fff928b67c45d391a0bfac1c0
const VOTE_HASH_LOW = 0x75ba32fff928b67c45d391a0bfac1c0
const VOTE_HASH_HIGH = 0x5a6ef60fd4d9b84327ba5c43cada66cd

# keccak256("EIP712Domain(string name,string version)")
# 0xb03948446334eb9b2196d5eb166f69b9d49403eb4a12f36de8d3f9f3cb8e15c3
const DOMAIN_HASH_LOW = 0xb03948446334eb9b2196d5eb166f69b9
const DOMAIN_HASH_HIGH = 0xd49403eb4a12f36de8d3f9f3cb8e15c3

func get_hash(calldata_len : felt, calldata : felt*) -> (hash : Uint256):
    return (Uint256(0, 0))
end

func authenticate_proposal(nonce : Uint256, target : felt, calldata_len : felt, calldata : felt*):
    # execution_hash should be in calldata[2] and calldata[3]
    let execution_hash = Uint256(calldata[2], calldata[3])

    #
    let (space) = felt_to_uint256(target)
    return ()
end

func authenticate_vote(nonce : Uint256, target : felt, calldata_len : felt, calldata : felt*):
    return ()
end

@external
func authenticate{syscall_ptr : felt*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
    nonce : Uint256, target : felt, function_selector : felt, calldata_len : felt, calldata : felt*
) -> ():
    if function_selector == PROPOSAL_SELECTOR:
        authenticate_proposal(nonce, target, calldata_len, calldata)
    else:
        authenticate_vote(nonce, target, calldata_len, calldata)
    end

    # Call the contract
    execute(nonce, target, function_selector, calldata_len, calldata)

    return ()
end
