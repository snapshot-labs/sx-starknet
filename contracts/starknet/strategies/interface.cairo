%lang starknet

from contracts.starknet.lib.types import EthAddress

# TODO: use L1Address instead of felt
@contract_interface
namespace IVotingStrategy:
    func get_voting_power(address : EthAddress, at : felt) -> (voting_power : felt):
    end
end
