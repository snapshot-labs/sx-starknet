/// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {TRUE, FALSE} from "../types.sol";

/// @title Space Manager
/// @notice Manages a whitelist of Spaces that are authorized to execute transactions via this contract.
contract StarknetSpaceManager is OwnableUpgradeable {
    /// @notice Thrown if a space is not in the whitelist.
    error InvalidSpace();

    /// @dev Mapping of spaces that are enabled.
    /// A uint256 is used as Starknet addresses cannot be cast to a solidity address type.
    mapping(uint256 spaces => uint256 isEnabled) internal spaces;

    /// @notice Emitted when a space is enabled.
    event SpaceEnabled(uint256 space);

    /// @notice Emitted when a space is disabled.
    event SpaceDisabled(uint256 space);

    /// @notice Initialize the contract with a list of Starknet spaces. Called only once.
    /// @param _spaces List of spaces.
    function __SpaceManager_init(uint256[] memory _spaces) internal onlyInitializing {
        for (uint256 i = 0; i < _spaces.length; i++) {
            if (_spaces[i] == 0 || (spaces[_spaces[i]] != FALSE)) revert InvalidSpace();
            spaces[_spaces[i]] = TRUE;
        }
    }

    /// @notice Enable a space.
    /// @param space Address of the space.
    function enableSpace(uint256 space) external onlyOwner {
        if (space == 0 || (spaces[space] != FALSE)) revert InvalidSpace();
        spaces[space] = TRUE;
        emit SpaceEnabled(space);
    }

    /// @notice Disable a space.
    /// @param space Address of the space.
    function disableSpace(uint256 space) external onlyOwner {
        if (spaces[space] == FALSE) revert InvalidSpace();
        spaces[space] = FALSE;
        emit SpaceDisabled(space);
    }

    /// @notice Check if a space is enabled.
    /// @param space Address of the space.
    /// @return uint256 whether the space is enabled.
    function isSpaceEnabled(uint256 space) external view returns (uint256) {
        return spaces[space];
    }

    modifier onlySpace(uint256 space) {
        if (spaces[space] == FALSE) revert InvalidSpace();
        _;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
     uint256[49] private __gap;
}
