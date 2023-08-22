#[starknet::contract]
mod EthRelayerExecutionStrategy {
    use array::ArrayTrait;
    use option::OptionTrait;
    use traits::{Into, TryInto};
    use serde::Serde;
    use starknet::EthAddress;
    use starknet::syscalls::send_message_to_l1_syscall;
    use starknet::info::get_caller_address;
    use sx::interfaces::IExecutionStrategy;
    use sx::types::{Proposal};

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl EthRelayerExecutionStrategy of IExecutionStrategy<ContractState> {
        fn execute(
            ref self: ContractState,
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
            payload: Array<felt252>
        ) {
            let space = get_caller_address();

            // Decode payload into L1 destination and L1 keccak execution hash
            let mut payload = payload.span();
            let (l1_destination, l1_execution_hash) = Serde::<(
                EthAddress, u256
            )>::deserialize(ref payload)
                .unwrap();

            let mut l1_payload = array![];
            space.serialize(ref l1_payload);
            proposal.serialize(ref l1_payload);
            votes_for.serialize(ref l1_payload);
            votes_against.serialize(ref l1_payload);
            votes_abstain.serialize(ref l1_payload);
            l1_execution_hash.serialize(ref l1_payload);

            send_message_to_l1_syscall(l1_destination.into(), l1_payload.span());
        }
    }
}
