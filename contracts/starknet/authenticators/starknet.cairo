%lang starknet
from starkware.starknet.common.syscalls import call_contract
from contracts.starknet.lib.hash_array import hash_array
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin

# Starknet key authenticator.
@external
func execute{
    syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*, ecdsa_ptr : SignatureBuiltin*
}(
    target : felt,
    function_selector : felt,
    calldata_len : felt,
    calldata : felt*,
    signer_len : felt,
    signer : felt*,
    signature_len : felt,
    signature : felt*,
) -> ():
    assert signature_len = 2
    assert signer_len = 1

    let (message_hash) = hash_array(calldata_len, calldata)

    verify_ecdsa_signature(
        message=message_hash,
        public_key=signer[0],
        signature_r=signature[0],
        signature_s=signature[1],
    )

    # Call the contract
    call_contract(
        contract_address=target,
        function_selector=function_selector,
        calldata_size=calldata_len,
        calldata=calldata,
    )

    return ()
end
