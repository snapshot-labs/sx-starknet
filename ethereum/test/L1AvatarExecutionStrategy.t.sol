// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Avatar} from "../src/mocks/Avatar.sol";
import {L1AvatarExecutionStrategy} from "../src/execution-strategies/L1AvatarExecutionStrategy.sol";
import {TRUE, FALSE} from "../src/types.sol";

/// @dev Tests for Setters on the L1 Avatar Execution Strategy
abstract contract L1AvatarExecutionStrategySettersTest is Test {
    error InvalidSpace();

    event L1AvatarExecutionStrategySetUp(
        address indexed _owner,
        address _target,
        address _starknetCore,
        uint256 _executionRelayer,
        uint256[] _starknetSpaces,
        uint256 _quorum
    );
    event TargetSet(address indexed newTarget);
    event QuorumUpdated(uint256 newQuorum);
    event ExecutionRelayerSet(uint256 indexed newExecutionRelayer);
    event SpaceEnabled(uint256 space);
    event SpaceDisabled(uint256 space);

    L1AvatarExecutionStrategy public avatarExecutionStrategy;
    Avatar public avatar;

    address public owner = address(0x1);
    address public starknetCore = address(0x2);
    address public unauthorized = address(0x3);

    uint256 quorum = 1;
    uint256 public ethRelayer = 2;
    uint256 public space = 3;

    function setUp() public virtual {
        avatar = new Avatar();
        vm.deal(address(avatar), 1000);
    }

    function testSetTarget() public {
        address newTarget = address(0xbeefe);
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit TargetSet(newTarget);
        avatarExecutionStrategy.setTarget(newTarget);
        assertEq(address(avatarExecutionStrategy.target()), newTarget);
    }

    function testUnauthorizedSetTarget() public {
        address newTarget = address(0xbeef);
        vm.prank(unauthorized);
        vm.expectRevert("Ownable: caller is not the owner");
        avatarExecutionStrategy.setTarget(newTarget);
    }

    function testSetQuorum() public {
        uint256 newQuorum = 3;
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit QuorumUpdated(newQuorum);
        avatarExecutionStrategy.setQuorum(newQuorum);
        assertEq(avatarExecutionStrategy.quorum(), newQuorum);
    }

    function testUnauthorizedSetQuorum() public {
        uint256 newQuorum = 3;
        vm.prank(unauthorized);
        vm.expectRevert("Ownable: caller is not the owner");
        avatarExecutionStrategy.setQuorum(newQuorum);
    }

    function testTransferOwnership() public {
        address newOwner = address(0xbeef);
        vm.prank(owner);
        avatarExecutionStrategy.transferOwnership(newOwner);
        assertEq(address(avatarExecutionStrategy.owner()), newOwner);
    }

    function testUnauthorizedTransferOwnership() public {
        address newOwner = address(0xbeef);
        vm.prank(unauthorized);
        vm.expectRevert("Ownable: caller is not the owner");
        avatarExecutionStrategy.transferOwnership(newOwner);
    }

    function testDoubleInitialization() public {
        vm.expectRevert("Initializable: contract is already initialized");
        address[] memory spaces = new address[](1);
        spaces[0] = address(this);
        avatarExecutionStrategy.setUp(abi.encode(owner, address(avatar), spaces));
    }

    function testEnableSpace() public {
        uint256 space_ = 2;
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit SpaceEnabled(space_);
        avatarExecutionStrategy.enableSpace(space_);
        assertEq(avatarExecutionStrategy.isSpaceEnabled(space_), TRUE);
    }

    function testEnableInvalidSpace() public {
        // Zero is not a valid space address
        uint256 space_ = 0;
        vm.prank(owner);
        vm.expectRevert(InvalidSpace.selector);
        avatarExecutionStrategy.enableSpace(space_);
    }

    function testEnableSpaceTwice() public {
        vm.prank(owner);
        vm.expectRevert(InvalidSpace.selector);
        avatarExecutionStrategy.enableSpace(space);
    }

    function testUnauthorizedEnableSpace() public {
        uint256 space_ = 2;
        vm.prank(unauthorized);
        vm.expectRevert("Ownable: caller is not the owner");
        avatarExecutionStrategy.enableSpace(space_);
    }

    function testDisableSpace() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit SpaceDisabled(space);
        avatarExecutionStrategy.disableSpace(space);
        assertEq(avatarExecutionStrategy.isSpaceEnabled(space), FALSE);
    }

    function testDisableInvalidSpace() public {
        // This space is not enabled
        uint256 space_ = 2;
        vm.prank(owner);
        vm.expectRevert(InvalidSpace.selector);
        avatarExecutionStrategy.disableSpace(space_);
    }

    function testUnauthorizedDisableSpace() public {
        vm.prank(unauthorized);
        vm.expectRevert("Ownable: caller is not the owner");
        avatarExecutionStrategy.disableSpace(space);
    }

    function testGetStrategyType() external {
        assertEq(avatarExecutionStrategy.getStrategyType(), "SimpleQuorumL1Avatar");
    }
}

contract AvatarExecutionStrategyTestDirect is L1AvatarExecutionStrategySettersTest {
    function setUp() public override {
        super.setUp();

        uint256[] memory spaces = new uint256[](1);
        spaces[0] = space;
        vm.expectEmit(true, true, true, true);
        emit L1AvatarExecutionStrategySetUp(owner, address(avatar), starknetCore, ethRelayer, spaces, quorum);
        avatarExecutionStrategy =
            new L1AvatarExecutionStrategy(owner, address(avatar), starknetCore, ethRelayer, spaces, quorum);
        avatar.enableModule(address(avatarExecutionStrategy));
    }
}

contract AvatarExecutionStrategyTestProxy is L1AvatarExecutionStrategySettersTest {
    function setUp() public override {
        super.setUp();

        uint256[] memory spaces = new uint256[](1);
        spaces[0] = space;
        vm.expectEmit(true, true, true, true);
        emit L1AvatarExecutionStrategySetUp(owner, address(avatar), starknetCore, ethRelayer, spaces, quorum);
        L1AvatarExecutionStrategy masterAvatarExecutionStrategy = new L1AvatarExecutionStrategy(
            owner, address(avatar), starknetCore, ethRelayer, spaces, quorum
        );

        avatarExecutionStrategy = L1AvatarExecutionStrategy(
            address(
                new ERC1967Proxy(
                    address(masterAvatarExecutionStrategy),
                    abi.encodeWithSelector(
                        L1AvatarExecutionStrategy.setUp.selector,
                        abi.encode(owner, address(avatar), starknetCore, ethRelayer, spaces, quorum)
                    )
                )
            )
        );
        avatar.enableModule(address(avatarExecutionStrategy));
    }
}
