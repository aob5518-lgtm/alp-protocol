// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { SponsorRegistry } from "../src/SponsorRegistry.sol";

contract SponsorRegistryTest is Test {
    SponsorRegistry internal registry;

    function setUp() public {
        registry = new SponsorRegistry(address(this));
    }

    function testAllowsGraphDepthBeyondLegacyHundredHopLimit() public {
        address[101] memory chain;
        for (uint256 i; i < chain.length; ++i) {
            chain[i] = address(uint160(100_000 + i));
        }

        for (uint256 i; i + 1 < chain.length; ++i) {
            vm.prank(chain[i]);
            registry.bindSponsor(chain[i + 1]);
        }

        address leaf = address(uint160(200_000));
        vm.prank(leaf);
        registry.bindSponsor(chain[0]);

        assertEq(registry.sponsorOf(leaf), chain[0]);
    }

    function testStillRejectsSponsorCycles() public {
        address alice = address(uint160(300_001));
        address bob = address(uint160(300_002));
        vm.prank(alice);
        registry.bindSponsor(bob);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(SponsorRegistry.SponsorCycle.selector, bob, alice));
        registry.bindSponsor(alice);
    }
}
