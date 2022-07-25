%lang starknet

@contract_interface
namespace IExecutionStrategy:
    func execute(proposal_outcome : felt, execution_params_len : felt, execution_params : felt*):
    end
end
