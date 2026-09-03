// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { ALPToken } from "../src/ALPToken.sol";
import { GenesisReserve } from "../src/GenesisReserve.sol";
import { GenesisReserveModule } from "./mocks/GenesisReserveModule.sol";

contract GenesisReserveTest is Test {
    GenesisReserve internal reserve;
    ALPToken internal alp;
    GenesisReserveModule internal module;
    address internal eoaRecipient = makeAddr("eoaRecipient");

    function setUp() public {
        reserve = new GenesisReserve(address(this));
        alp = new ALPToken(
            address(reserve),
            address(this),
            makeAddr("buyback"),
            makeAddr("top100"),
            makeAddr("nodeAirdrop"),
            makeAddr("community"),
            makeAddr("development")
        );
        reserve.configureToken(address(alp));
        module = new GenesisReserveModule();
    }

    function testReserveRejectsEOAAndUnregisteredRecipients() public {
        vm.expectRevert(
            abi.encodeWithSelector(GenesisReserve.ModuleMustBeContract.selector, eoaRecipient)
        );
        reserve.setProtocolModule(eoaRecipient, true);

        reserve.setProtocolModule(address(module), true);
        vm.expectRevert(
            abi.encodeWithSelector(GenesisReserve.RecipientNotProtocolModule.selector, eoaRecipient)
        );
        module.release(reserve, eoaRecipient, 1 ether, keccak256("TEST"));
    }

    function testRegisteredProtocolModuleCanOnlyReleaseToRegisteredProtocolModule() public {
        reserve.setProtocolModule(address(module), true);
        module.release(reserve, address(module), 5 ether, keccak256("TEST"));

        assertEq(alp.balanceOf(address(module)), 5 ether);
        assertEq(alp.balanceOf(address(reserve)), 210_000_000 ether - 5 ether);
    }
}
