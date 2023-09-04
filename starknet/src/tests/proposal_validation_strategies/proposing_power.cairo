#[cfg(test)]
mod tests {
    use starknet::syscalls::deploy_syscall;
    use starknet::SyscallResult;
    use starknet::contract_address_const;
    use starknet::ContractAddress;
    use sx::{
        voting_strategies::{
            vanilla::VanillaVotingStrategy, merkle_whitelist::MerkleWhitelistVotingStrategy,
            erc20_votes::ERC20VotesVotingStrategy
        },
        utils::{merkle::Leaf},
        proposal_validation_strategies::proposing_power::{ProposingPowerProposalValidationStrategy},
        interfaces::{
            IProposalValidationStrategy, IProposalValidationStrategyDispatcher,
            IProposalValidationStrategyDispatcherTrait
        },
        types::{IndexedStrategy, Strategy, UserAddress},
        tests::{
            test_merkle_whitelist::merkle_utils::{
                generate_merkle_data, generate_merkle_root, generate_proof
            },
            mocks::erc20_votes_preset::ERC20VotesPreset
        }
    };
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::governance::utils::interfaces::votes::{
        IVotes, IVotesDispatcher, IVotesDispatcherTrait
    };

    #[test]
    #[available_gas(10000000000)]
    fn test_vanilla_works() {
        starknet::testing::set_block_timestamp(1);

        // deploy vanilla voting strategy
        let (vanilla_contract, _) = deploy_syscall(
            VanillaVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
        )
            .unwrap();

        let vanilla_strategy = Strategy { address: vanilla_contract, params: array![], };

        // create a proposal validation strategy
        let (proposal_validation_contract, _) = deploy_syscall(
            ProposingPowerProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![].span(),
            false
        )
            .unwrap();

        let allowed_strategies = array![vanilla_strategy.clone()];
        let proposal_threshold = 1_u256;
        let mut params = array![];
        proposal_threshold.serialize(ref params);
        allowed_strategies.serialize(ref params);

        // used strategies
        let used_strategy = IndexedStrategy { index: 0, params: array![], };
        let used_strategies = array![used_strategy.clone()];
        let mut user_params = array![];
        used_strategies.serialize(ref user_params);

        let contract = IProposalValidationStrategyDispatcher {
            contract_address: proposal_validation_contract,
        };

        let author = UserAddress::Starknet(contract_address_const::<0x123456789>());

        // Vanilla should return 1 so it should be fine
        let is_validated = contract.validate(author, params.span(), user_params.span());
        assert(is_validated, 'not enough VP');

        // Now increase threshold
        let proposal_threshold = 2_u256;
        let mut params = array![];
        proposal_threshold.serialize(ref params);
        allowed_strategies.serialize(ref params);

        // Threshold is 2 but VP should be 1
        let is_validated = contract.validate(author, params.span(), user_params.span());
        assert(!is_validated, 'Threshold should not be reached');

        // But now if we add the vanilla voting strategy twice then it should be fine
        let allowed_strategies = array![
            vanilla_strategy.clone(), vanilla_strategy.clone()
        ]; // Add it twice
        let proposal_threshold = 2_u256; // Threshold is still 2
        let mut params = array![];
        proposal_threshold.serialize(ref params);
        allowed_strategies.serialize(ref params);

        let used_strategy1 = used_strategy;
        let used_strategy2 = IndexedStrategy { index: 1, params: array![], };
        let used_strategies = array![used_strategy1, used_strategy2];
        let mut user_params = array![];
        used_strategies.serialize(ref user_params);

        let is_validated = contract.validate(author, params.span(), user_params.span());
        assert(is_validated, 'should have 2 VP');
    }

    #[test]
    #[available_gas(10000000000)]
    fn test_merkle_whitelist_works() {
        starknet::testing::set_block_timestamp(1);

        // deploy merkle whitelist contract
        let (merkle_contract, _) = deploy_syscall(
            MerkleWhitelistVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![].span(),
            false
        )
            .unwrap();

        // create proposal validation strategy based on the deployed merkle whitelist contract
        let (proposal_validation_contract, _) = deploy_syscall(
            ProposingPowerProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![].span(),
            false
        )
            .unwrap();

        let contract = IProposalValidationStrategyDispatcher {
            contract_address: proposal_validation_contract,
        };

        // Generate leaves
        let voter1 = UserAddress::Starknet(contract_address_const::<0x111111>());
        let voter2 = UserAddress::Starknet(contract_address_const::<0x111112>());
        let voter3 = UserAddress::Starknet(contract_address_const::<0x111113>());
        let leaf1 = Leaf { address: voter1, voting_power: 1 };
        let leaf2 = Leaf { address: voter2, voting_power: 2 };
        let leaf3 = Leaf { address: voter3, voting_power: 3 };

        let members = array![leaf1, leaf2, leaf3];

        let merkle_data = generate_merkle_data(members.span());

        let proof1 = generate_proof(merkle_data.span(), 0);
        let proof2 = generate_proof(merkle_data.span(), 1);
        let proof3 = generate_proof(merkle_data.span(), 2);

        let mut user_params = ArrayTrait::<felt252>::new();
        leaf1.serialize(ref user_params);
        proof1.serialize(ref user_params);

        let root = generate_merkle_root(merkle_data.span());
        let merkle_whitelist_strategy = Strategy {
            address: merkle_contract, params: array![root],
        };
        let allowed_strategies = array![merkle_whitelist_strategy.clone()];
        let proposal_threshold =
            2_u256; // voter1 should not hit threshold but voter2 and voter3 should

        let mut params = array![];
        proposal_threshold.serialize(ref params);
        allowed_strategies.serialize(ref params);

        // setup for voter1
        let author = leaf1.address;
        let mut indexed_params = array![];
        leaf1.serialize(ref indexed_params);
        proof1.serialize(ref indexed_params);
        let used_strategy = IndexedStrategy { index: 0, params: indexed_params, };
        let used_strategies = array![used_strategy.clone()];
        let mut user_params = array![];
        used_strategies.serialize(ref user_params);

        let is_validated = contract.validate(author, params.span(), user_params.span());
        assert(!is_validated, 'should not have enough VP');

        // setup for voter2
        let author = leaf2.address;
        let mut indexed_params = array![];
        leaf2.serialize(ref indexed_params);
        proof2.serialize(ref indexed_params);
        let used_strategy = IndexedStrategy { index: 0, params: indexed_params, };
        let used_strategies = array![used_strategy.clone()];
        let mut user_params = array![];
        used_strategies.serialize(ref user_params);

        let is_validated = contract.validate(author, params.span(), user_params.span());
        assert(is_validated, 'should have enough VP1');

        // setup for voter3
        let author = leaf3.address;
        let mut indexed_params = array![];
        leaf3.serialize(ref indexed_params);
        proof3.serialize(ref indexed_params);
        let used_strategy = IndexedStrategy { index: 0, params: indexed_params, };
        let used_strategies = array![used_strategy.clone()];
        let mut user_params = array![];
        used_strategies.serialize(ref user_params);

        let is_validated = contract.validate(author, params.span(), user_params.span());
        assert(is_validated, 'should have enough VP2');

        // -- Now let's mix merkle and vanilla voting strategies --

        // deploy vanilla voting strategy
        let (vanilla_contract, _) = deploy_syscall(
            VanillaVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
        )
            .unwrap();

        let vanilla_strategy = Strategy { address: vanilla_contract, params: array![], };

        let allowed_strategies = array![
            merkle_whitelist_strategy.clone(), vanilla_strategy.clone()
        ]; // update allowed strategies
        let proposal_threshold = proposal_threshold; // threshold is left unchanged
        let mut params = array![]; // update params
        proposal_threshold.serialize(ref params);
        allowed_strategies.serialize(ref params);

        // voter 1 should now have enough voting power!
        let author = leaf1.address;
        let vanilla = IndexedStrategy { index: 1, params: array![], };
        let mut indexed_params = array![];
        leaf1.serialize(ref indexed_params);
        proof1.serialize(ref indexed_params);
        let merkle = IndexedStrategy { index: 0, params: indexed_params, };

        let used_strategies = array![vanilla.clone(), merkle.clone()];
        let mut user_params = array![];
        used_strategies.serialize(ref user_params);

        let is_validated = contract.validate(author, params.span(), user_params.span());
        assert(is_validated, 'should have enough VP2');

        // and a random voter that doesn't use the whitelist should not have enough VP
        let author = UserAddress::Starknet(contract_address_const::<0x123456789>());
        let used_strategies = array![vanilla.clone()];
        let mut user_params = array![];
        used_strategies.serialize(ref user_params);

        let is_validated = contract.validate(author, params.span(), user_params.span());
        assert(!is_validated, 'should not have enough VP');
    }

    fn strategy_from_contract(token_contract: ContractAddress) -> Strategy {
        let (contract, _) = deploy_syscall(
            ERC20VotesVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![].span(),
            false,
        )
            .unwrap();

        let params: Array<felt252> = array![token_contract.into()];

        Strategy { address: contract, params, }
    }

    #[test]
    #[available_gas(10000000000)]
    fn test_erc20votes_works() {
        let SUPPLY = 100_u256;

        // deploy erc20 voting strategy
        let owner = contract_address_const::<'owner'>();
        let mut constructor = array!['TEST', 'TST'];
        SUPPLY.serialize(ref constructor);
        owner.serialize(ref constructor);

        let (erc20_contract, _) = deploy_syscall(
            ERC20VotesPreset::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor.span(), false
        )
            .unwrap();

        let erc20 = IVotesDispatcher { contract_address: erc20_contract, };

        let erc20_strategy = strategy_from_contract(erc20_contract);

        starknet::testing::set_contract_address(owner);
        erc20.delegate(owner);

        // advance block timestamp
        starknet::testing::set_block_timestamp(1);

        // create a proposal validation strategy
        let (proposal_validation_contract, _) = deploy_syscall(
            ProposingPowerProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![].span(),
            false
        )
            .unwrap();

        let allowed_strategies = array![erc20_strategy.clone()];
        let mut params = array![];
        let proposal_threshold = SUPPLY;
        proposal_threshold.serialize(ref params);
        allowed_strategies.serialize(ref params);

        // used strategies
        let used_strategy = IndexedStrategy { index: 0, params: array![], };
        let used_strategies = array![used_strategy.clone()];
        let mut user_params = array![];
        used_strategies.serialize(ref user_params);

        let contract = IProposalValidationStrategyDispatcher {
            contract_address: proposal_validation_contract,
        };

        let author = UserAddress::Starknet(owner);

        let is_validated = contract.validate(author, params.span(), user_params.span());
        assert(is_validated, 'not enough VP');

        // Now increase threshold
        let proposal_threshold = SUPPLY + 1;
        let mut params = array![];
        proposal_threshold.serialize(ref params);
        allowed_strategies.serialize(ref params);

        let is_validated = contract.validate(author, params.span(), user_params.span());
        assert(!is_validated, 'Threshold should not be reached');
    }
}
