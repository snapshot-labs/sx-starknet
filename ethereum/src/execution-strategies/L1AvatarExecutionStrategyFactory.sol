/// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/Clones.sol";
import {L1AvatarExecutionStrategy} from "./L1AvatarExecutionStrategy.sol";

/// @title L1 Avatar Execution Strategy Factory
/// @notice Used to deploy new L1 Avatar Execution Strategy contracts.
contract L1AvatarExecutionStrategyFactory {
    address public implementation;
    L1AvatarExecutionStrategy[] public deployedContracts;

    event ContractDeployed(address indexed contractAddress);

    constructor(address _implementation) {
        implementation = _implementation;
    }

    /// @notice Deploys a new L1 Avatar Execution Strategy contract.
    /// @param _owner Address of the owner of this contract.
    /// @param _target Address of the avatar that this module will pass transactions to.
    /// @param _starknetCore Address of the StarkNet Core contract.
    /// @param _executionRelayer Address of the StarkNet contract that will send execution details to this contract in a L2 -> L1 message
    /// @param _starknetSpaces Array of whitelisted space contracts.
    /// @param _quorum The quorum required to execute a proposal.
    function createContract(
        address _owner,
        address _target,
        address _starknetCore,
        uint256 _executionRelayer,
        uint256[] memory _starknetSpaces,
        uint256 _quorum
    ) public {
        address clone = Clones.clone(implementation);

        L1AvatarExecutionStrategy(clone).setUp(
            _owner, _target, _starknetCore, _executionRelayer, _starknetSpaces, _quorum
        );
        deployedContracts.push(L1AvatarExecutionStrategy(clone));
        emit ContractDeployed(clone);
    }
}
