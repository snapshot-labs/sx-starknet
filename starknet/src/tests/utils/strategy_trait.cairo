use array::ArrayTrait;
use sx::types::Strategy;
use starknet::{ContractAddress, contract_address_const};

trait StrategyTrait {
    fn test_value() -> Strategy;
    fn from_address(addr: ContractAddress) -> Strategy;
}

impl StrategyImpl of StrategyTrait {
    fn test_value() -> Strategy {
        Strategy {
            address: contract_address_const::<0x5c011>(), params: ArrayTrait::<felt252>::new(), 
        }
    }

    fn from_address(addr: ContractAddress) -> Strategy {
        Strategy { address: addr, params: ArrayTrait::<felt252>::new(),  }
    }
}
