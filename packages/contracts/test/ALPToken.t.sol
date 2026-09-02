// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ALPToken} from "../src/ALPToken.sol";

contract ALPTokenTest is Test {
    address internal reserve = makeAddr("reserve");
    address internal pair = makeAddr("pair");
    address internal seller = makeAddr("seller");
    address internal buyer = makeAddr("buyer");
    address internal buyback = makeAddr("buyback");
    address internal top100 = makeAddr("top100");
    address internal nodeAirdrop = makeAddr("nodeAirdrop");
    address internal community = makeAddr("community");
    address internal development = makeAddr("development");
    ALPToken internal alp;

    function setUp() public {
        alp = new ALPToken(reserve, address(this), buyback, top100, nodeAirdrop, community, development);
        alp.configureMainPair(pair);
        alp.setSellFeeExempt(reserve, true);
        vm.prank(reserve);
        alp.transfer(seller, 100 ether);
    }

    function testFixedGenesisSupplyAndNoInflationSurface() public view {
        assertEq(alp.totalSupply(), 210_000_000 ether);
        assertEq(alp.balanceOf(reserve), 210_000_000 ether - 100 ether);
    }

    function testSellDeductsExactlySeventeenPercentAndConservesBalance() public {
        vm.prank(seller);
        alp.transfer(pair, 100 ether);

        assertEq(alp.balanceOf(pair), 83 ether);
        assertEq(alp.balanceOf(buyback), 5 ether);
        assertEq(alp.balanceOf(top100), 1 ether);
        assertEq(alp.balanceOf(nodeAirdrop), 4 ether);
        assertEq(alp.balanceOf(community), 5 ether);
        assertEq(alp.balanceOf(development), 2 ether);
        assertEq(alp.totalSupply(), 210_000_000 ether);
    }

    function testPairBuyRevertsUnlessRecipientWhitelisted() public {
        vm.prank(reserve);
        alp.transfer(pair, 1 ether);
        vm.prank(pair);
        vm.expectRevert(abi.encodeWithSelector(ALPToken.ALPBuyRestricted.selector, buyer));
        alp.transfer(buyer, 1 ether);

        alp.setBuyWhitelist(buyer, true);
        vm.prank(pair);
        alp.transfer(buyer, 1 ether);
        assertEq(alp.balanceOf(buyer), 1 ether);
    }

    function testFuzzSellConservesAllTokens(uint96 rawAmount) public {
        uint256 amount = bound(uint256(rawAmount), 1, 100 ether);
        vm.prank(seller);
        alp.transfer(pair, amount);
        assertEq(alp.balanceOf(seller) + alp.balanceOf(pair) + alp.balanceOf(buyback) + alp.balanceOf(top100)
            + alp.balanceOf(nodeAirdrop) + alp.balanceOf(community) + alp.balanceOf(development), 100 ether);
    }
}
