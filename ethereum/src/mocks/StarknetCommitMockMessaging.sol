/// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./MockStarknetMessaging.sol";

/// @title Starknet Commit Contract
/// @notice Allows data to be committed to Starknet via a transaction on L1. The contract works in combination with a corresponding authenticator contract on Starknet.
contract StarknetCommitMockMessaging {
    /// @notice The Starknet core contract.
    MockStarknetMessaging public immutable starknetCore;

    /// @dev Selector for the L1 handler in the authenticator on Starknet:
    uint256 private constant L1_COMMIT_HANDLER =
        674623595553689999852507866835294387286428733459551884504121875060358224925;

    /// @notice Emitted when a hash is committed.
    event Commit(uint256 starknetAuthenticator, uint256 _hash, bytes32 msgHash, uint256 msgNonce);

    constructor(MockStarknetMessaging _starknetCore) {
        starknetCore = _starknetCore;
    }

    /// @notice Commits a hash and the sender address to Starknet.
    /// @param starknetAuthenticator The address of the authenticator contract on Starknet that will receive the message.
    ///@param _hash The hash to commit
    function commit(uint256 starknetAuthenticator, uint256 _hash) external payable {
        uint256[] memory payload = new uint256[](2);
        payload[0] = uint256(uint160(msg.sender));
        payload[1] = _hash;
        (bytes32 msgHash, uint256 msgNonce) =
            starknetCore.sendMessageToL2{value: msg.value}(starknetAuthenticator, L1_COMMIT_HANDLER, payload);
        emit Commit(starknetAuthenticator, _hash, msgHash, msgNonce);
    }
}
