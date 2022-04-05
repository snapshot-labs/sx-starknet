// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IStarknetCore {
  function consumeMessageFromL2(uint256 fromAddress, uint256[] calldata payload)
    external
    returns (bytes32);

  function l2ToL1Messages(bytes32 msgHash) external view returns (uint256);
}
