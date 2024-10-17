use sx::tests::mocks::{
    timestamp_remappers::MockTimestampRemappers, facts_registry::MockFactsRegistry
};
use starknet::ContractAddress;
use sx::external::herodotus::BinarySearchTree;

fn deploy_timestamp_remappers() -> ContractAddress {
    let (contract_address, _) = starknet::syscalls::deploy_syscall(
        MockTimestampRemappers::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false,
    )
        .unwrap();
    contract_address
}

fn deploy_facts_registry() -> ContractAddress {
    let (contract_address, _) = starknet::syscalls::deploy_syscall(
        MockFactsRegistry::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false,
    )
        .unwrap();
    contract_address
}

impl DefaultBinarySearchTree of Default<BinarySearchTree> {
    fn default() -> BinarySearchTree {
        BinarySearchTree {
            mapper_id: 1,
            last_pos: 1,
            peaks: array![].span(),
            proofs: array![].span(),
            left_neighbor: Option::None,
        }
    }
}
