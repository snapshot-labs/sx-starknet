/// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

interface IStarknetCore {
  function sendMessageToL2(
    uint256 to_address,
    uint256 selector,
    uint256[] calldata payload
  ) external returns (bytes32);

  function consumeMessageFromL2(uint256 fromAddress, uint256[] calldata payload)
    external
    returns (bytes32);

  function l2ToL1Messages(bytes32 msgHash) external view returns (uint256);
}
