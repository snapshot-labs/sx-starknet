%lang starknet

@contract_interface
namespace i_authenticator:
    func execute(target : felt, function_selector : felt, calldata_len : felt, calldata : felt*):
    end
end
