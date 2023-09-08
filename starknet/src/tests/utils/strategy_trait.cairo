use sx::types::Strategy;
use starknet::{ContractAddress, contract_address_const};

trait StrategyTrait {
    fn from_address(addr: ContractAddress) -> Strategy;
}

impl StrategyDefault of Default<Strategy> {
    fn default() -> Strategy {
        Strategy { address: contract_address_const::<'snapshot'>(), params: array![], }
    }
}

impl StrategyImpl of StrategyTrait {
    fn from_address(addr: ContractAddress) -> Strategy {
        Strategy { address: addr, params: array![], }
    }
}
