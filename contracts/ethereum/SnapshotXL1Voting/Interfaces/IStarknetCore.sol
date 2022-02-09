/// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

interface IStarknetCore {
  function sendMessageToL2(
    uint256 to_address,
    uint256 selector,
    uint256[] calldata payload
  ) external returns (bytes32);
}
