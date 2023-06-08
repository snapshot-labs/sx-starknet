mod i_voting_strategy;
mod i_execution_strategy;
mod i_proposal_validation_strategy;

use i_voting_strategy::{IVotingStrategy, IVotingStrategyDispatcher, IVotingStrategyDispatcherTrait};
use i_execution_strategy::{
    IExecutionStrategy, IExecutionStrategyDispatcher, IExecutionStrategyDispatcherTrait
};
use i_proposal_validation_strategy::{
    IProposalValidationStrategy, IProposalValidationStrategyDispatcher,
    IProposalValidationStrategyDispatcherTrait
};
