use sx::types::user_address::UserAddressTrait;
#[starknet::contract]
mod ERC20VotesVotingStrategy {
    use sx::interfaces::IVotingStrategy;
    use sx::types::{UserAddress, UserAddressTrait};
    use starknet::ContractAddress;
    use serde::Serde;
    use array::{ArrayTrait, SpanTrait};
    use openzeppelin::governance::utils::interfaces::votes::{
        IVotes, IVotesDispatcher, IVotesDispatcherTrait
    };
    use traits::Into;
    use debug::PrintTrait;

    use option::OptionTrait;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl ERC20VotesVotingStrategy of IVotingStrategy<ContractState> {
        fn get_voting_power(
            self: @ContractState,
            block_number: u32,
            voter: UserAddress,
            params: Array<felt252>,
            user_params: Array<felt252>,
        ) -> u256 {
            // Cast voter address to a Starknet address
            // Will revert if the address is not a Starknet address
            let voter = voter.to_starknet_address();

            // Get the ERC20 contract address from the params array
            let mut params_span = params.span();
            let erc20_contract_address = Serde::<ContractAddress>::deserialize(ref params_span)
                .unwrap();

            let erc20 = IVotesDispatcher { contract_address: erc20_contract_address,  };

            block_number.print();
            erc20.get_past_votes(voter, block_number.into() - 1) // TODO; verify - 1
        }
    }
}
