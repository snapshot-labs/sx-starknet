%lang starknet

@contract_interface
namespace i_authenticator:
    func execute(
        target : felt,
        function_selector : felt,
        calldata_len : felt,
        calldata : felt*,
        signer_len : felt,
        signer : felt*,
        signature_len : felt,
        signature : felt*,
    ):
    end
end
