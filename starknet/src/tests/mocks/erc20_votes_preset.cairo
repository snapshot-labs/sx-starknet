// Needed until Scarb fixes https://github.com/software-mansion/scarb/discussions/568#discussioncomment-6742412
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (token/erc20/presets/erc20votes.cairo)

/// ERC20 with the ERC20Votes extension.
#[starknet::contract]
mod ERC20VotesPreset {
    use openzeppelin::governance::utils::interfaces::IVotes;
    use openzeppelin::token::erc20::{ERC20Component};
    use openzeppelin::token::erc20::extensions::{ERC20VotesComponent};
    use openzeppelin::utils::nonces::NoncesComponent;
    use openzeppelin::utils::structs::checkpoint::Checkpoint;
    use openzeppelin::utils::cryptography::snip12::{SNIP12Metadata};
    use starknet::ContractAddress;
    use starknet::contract_address_const;


    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: ERC20VotesComponent, storage: erc20_votes, event: ERC20VotesEvent);
    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC20VotesImpl = ERC20VotesComponent::ERC20VotesImpl<ContractState>;
    impl ERC20VotesInternalImpl = ERC20VotesComponent::InternalImpl<ContractState>;

    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;

    impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'toto' // TODO
        }

        fn version() -> felt252 {
            '1.0.0' // TODO
        }
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        erc20_votes: ERC20VotesComponent::Storage,
        #[substorage(v0)]
        nonces: NoncesComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        ERC20VotesEvent: ERC20VotesComponent::Event,
        #[flat]
        NoncesEvent: NoncesComponent::Event,
    }

    //
    // Hooks
    //

    impl ERC20VotesHooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) { // Nothing to do
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            // Access local state from component state
            let mut contract_state = ERC20Component::HasComponent::get_contract_mut(ref self);
            // Function from integrated component
            contract_state.erc20_votes.transfer_voting_units(from, recipient, amount);
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20._mint(recipient, initial_supply);
    }

    /// Get number of checkpoints for `account`.
    #[abi(embed_v0)]
    fn num_checkpoints(self: @ContractState, account: ContractAddress) -> u32 {
        self.erc20_votes.num_checkpoints(account)
    }

    /// Get the `pos`-th checkpoint for `account`.
    #[abi(embed_v0)]
    fn checkpoints(self: @ContractState, account: ContractAddress, pos: u32) -> Checkpoint {
        self.erc20_votes.checkpoints(account, pos)
    }
}
