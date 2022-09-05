%lang starknet

from contracts.starknet.lib.execute import execute
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from contracts.starknet.lib.stark_sig import StarkSig

# getSelectorFromName("propose")
const PROPOSAL_SELECTOR = 0x1bfd596ae442867ef71ca523061610682af8b00fc2738329422f4ad8d220b81
# getSelectorFromName("vote")
const VOTE_SELECTOR = 0x132bdf85fc8aa10ac3c22f02317f8f53d4b4f52235ed1eabb3a4cbbe08b5c41

@external
func authenticate{
    syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*, ecdsa_ptr : SignatureBuiltin*
}(
    r : felt,
    s : felt,
    salt : felt,
    target : felt,
    function_selector : felt,
    calldata_len : felt,
    calldata : felt*,
) -> ():
    if function_selector == PROPOSAL_SELECTOR:
        StarkSig.verify_propose_sig(r, s, salt, target, calldata_len, calldata)
    else:
        if function_selector == VOTE_SELECTOR:
            StarkSig.verify_vote_sig(r, s, salt, target, calldata_len, calldata)
        else:
            # Invalid selector
            return ()
        end
    end

    # Call the contract
    execute(target, function_selector, calldata_len, calldata)
    return ()
end
