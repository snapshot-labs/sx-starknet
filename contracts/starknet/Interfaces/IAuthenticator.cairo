%lang starknet

@contract_interface
namespace IAuthenticator:
    func execute(target : felt, function_selector : felt, calldata_len : felt, calldata : felt*):
    end
end
