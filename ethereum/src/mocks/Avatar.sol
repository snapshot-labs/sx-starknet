// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IAvatar} from "@gnosis.pm/zodiac/contracts/interfaces/IAvatar.sol";

contract Avatar {
    error NotAuthorized();

    mapping(address module => bool isEnabled) internal modules;

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    function enableModule(address _module) external {
        modules[_module] = true;
    }

    function disableModule(address _module) external {
        modules[_module] = false;
    }

    function isModuleEnabled(address _module) external view returns (bool) {
        return modules[_module];
    }

    function execTransactionFromModule(address payable to, uint256 value, bytes calldata data, uint8 operation)
        external
        returns (bool success)
    {
        if (!modules[msg.sender]) revert NotAuthorized();
        // solhint-disable-next-line avoid-low-level-calls
        if (operation == 1) (success,) = to.delegatecall(data);
        else (success,) = to.call{value: value}(data);
    }

    function getModulesPaginated(
        address,
        uint256 // pageSize
    ) external pure returns (address[] memory array, address next) {
        // Unimplemented
        return (new address[](0), address(0));
    }
}
