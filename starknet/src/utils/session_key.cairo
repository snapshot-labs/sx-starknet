#[starknet::contract]
mod SessionKey {
    use starknet::EthAddress;
    use sx::types::UserAddress;

    #[storage]
    struct Storage {
        _owner: LegacyMap::<felt252, UserAddress>,
        _end_timestamp: LegacyMap::<felt252, u32>,
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn register(
            user_address: UserAddress, session_public_key: felt252, session_duration: u32
        ) {}

        fn revoke(session_public_key: felt252) {}
    }
}
