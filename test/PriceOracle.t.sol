// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@forge-std/Test.sol";
import "../src/PriceOracle.sol";

contract PriceOracleTest is Test {
    PriceOracle private priceOracle;
    address private owner = address(0x420);
    address private user1 = address(0x069);

    function setUp() public {
        vm.startPrank(owner);
        priceOracle = new PriceOracle();
        vm.stopPrank();
    }

    function test_SetTokenPriceInWETHByOwner() public {
        vm.startPrank(owner);
        // set oROR price to 0.00001 WETH
        priceOracle.setTokenPriceInWETH(priceOracle.oROR(), 0.00001 * 10 ** 18);
        assertEq(priceOracle.getValueInWETH(priceOracle.oROR()), 0.00001 * 10 ** 18);
        vm.stopPrank();
    }

    function test_SetWETHPriceInUSDByOwner() public {
        vm.startPrank(owner);
        priceOracle.setWETHPriceInUSD(3000 * 10 ** 18);
        assertEq(priceOracle.getValueInWETH(priceOracle.WETH()), 3000 * 10 ** 18);
        vm.stopPrank();
    }

    function testFailNonOwnerSetTokenPrice() public {
        vm.startPrank(user1);
        // attempt to set oROR price as non-owner
        priceOracle.setTokenPriceInWETH(priceOracle.oROR(), 0.00001 * 10 ** 18);
        vm.stopPrank();
    }

    function testFailNonOwnerSetWETHPriceInUSD() public {
        vm.startPrank(user1);
        priceOracle.setWETHPriceInUSD(3000 * 10 ** 18);
        vm.stopPrank();
    }
}
