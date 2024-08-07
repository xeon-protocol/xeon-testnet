// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PriceOracle.sol";

contract PriceOracleTest is Test {
    PriceOracle private priceOracle;
    address private owner = address(0x123);
    address private nonAdmin = address(0x789);

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

    function test_NonOwnerCannotSetTokenPriceInWETH() public {
        vm.startPrank(nonAdmin);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonAdmin));
        // attempt to set oROR price as non-owner
        priceOracle.setTokenPriceInWETH(priceOracle.oROR(), 0.00001 * 10 ** 18);
        vm.stopPrank();
    }

    function test_NonOwnerCannotSetWETHPriceInUSD() public {
        vm.startPrank(nonAdmin);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonAdmin));
        priceOracle.setWETHPriceInUSD(3000 * 10 ** 18);
        vm.stopPrank();
    }
}
