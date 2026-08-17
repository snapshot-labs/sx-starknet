use sx::tests::mocks::satellite::MockSatellite;
use starknet::ContractAddress;

fn deploy_satellite() -> ContractAddress {
    let (contract_address, _) = starknet::syscalls::deploy_syscall(
        MockSatellite::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false,
    )
        .unwrap();
    contract_address
}
