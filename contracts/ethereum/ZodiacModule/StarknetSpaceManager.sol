/// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

/// @title Space Manager - A contract that manages SX spaces on Starknet that are able to execute transactions via this contract
/// @author Snapshot Labs
contract StarknetSpaceManager is OwnableUpgradeable {
  error InvalidSpace();

  /// @dev Mapping of spaces that are enabled.
  /// A uint256 is used as Starknet addresses cannot be cast to a solidity address type.
  mapping(uint256 => bool) internal spaces;

  /// @notice Emitted when a space is enabled.
  event SpaceEnabled(uint256 space);

  /// @notice Emitted when a space is disabled.
  event SpaceDisabled(uint256 space);

  /// @notice Initialize the contract with a list of spaces. Called only once.
  /// @param _spaces List of spaces.
  function __SpaceManager_init(uint256[] memory _spaces) internal initializer {
    for (uint256 i = 0; i < _spaces.length; i++) {
      spaces[_spaces[i]] = true;
    }
  }

  /// @notice Enable a space.
  /// @param space Address of the space.
  function enableSpace(uint256 space) public onlyOwner {
    if (space == 0 || isSpaceEnabled(space)) revert InvalidSpace();
    spaces[space] = true;
    emit SpaceEnabled(space);
  }

  /// @notice Disable a space.
  /// @param space Address of the space.
  function disableSpace(uint256 space) public onlyOwner {
    if (!spaces[space]) revert InvalidSpace();
    spaces[space] = false;
    emit SpaceDisabled(space);
  }

  /// @notice Check if a space is enabled.
  /// @param space Address of the space.
  /// @return bool whether the space is enabled.
  function isSpaceEnabled(uint256 space) public view returns (bool) {
    return spaces[space];
  }

  modifier onlySpace(uint256 callerAddress) {
    if (!spaces[callerAddress]) revert InvalidSpace();
    _;
  }
}
