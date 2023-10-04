mod authenticators {
    mod stark_tx;
}

mod execution_strategies {
    mod vanilla;
}


mod proposal_validation_strategies {
    mod proposition_power;
}

mod voting_strategies {
    mod erc20_votes;

    mod merkle_whitelist;
}

mod factory {
    mod factory;
}

mod space {
    mod space;

    mod update_settings;

    mod upgrade;

    mod vote;
}

mod mocks {
    mod erc20_votes_preset;
    mod executor;
    mod no_voting_power;
    mod proposal_validation_always_fail;
    mod space_v2;
    mod simple_quorum;
    mod vanilla_authenticator;
    mod vanilla_execution_strategy;
    mod vanilla_proposal_validation;
    mod vanilla_voting_strategy;
    mod account;
}

use openzeppelin::account::Account;

mod setup {
    mod setup;
}

mod utils {
    mod strategy_trait;
    mod i_quorum;
}
