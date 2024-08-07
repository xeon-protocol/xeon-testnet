// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PriceOracle.sol";

contract PriceOracleTest is Test {
    PriceOracle private priceOracle;
    address private owner = address(0x123);
    address private admin = address(0x456);
    address private nonAdmin = address(0x789);

    function setUp() public {
        vm.startPrank(owner);
        priceOracle = new PriceOracle();
        priceOracle.addAdmin(admin);
        vm.stopPrank();
    }

    function test_SetTokenPriceInWETHByAdmin() public {
        vm.startPrank(admin);
        // set oROR price to 0.00001 WETH
        priceOracle.setTokenPriceInWETH(priceOracle.oROR(), 0.00001 * 10 ** 18);
        assertEq(priceOracle.getValueInWETH(priceOracle.oROR()), 0.00001 * 10 ** 18);
        vm.stopPrank();
    }

    function test_SetWETHPriceInUSDByAdmin() public {
        vm.startPrank(admin);
        priceOracle.setWETHPriceInUSD(3000 * 10 ** 18);

        assertEq(priceOracle.getValueInWETH(priceOracle.WETH()), 3000 * 10 ** 18);
        vm.stopPrank();
    }

    function test_NonAdminCannotSetTokenPriceInWETH() public {
        vm.startPrank(nonAdmin);
        vm.expectRevert("Caller is not an admin");
        // attempt to set oROR price as non-admin
        priceOracle.setTokenPriceInWETH(priceOracle.oROR(), 0.00001 * 10 ** 18);
        vm.stopPrank();
    }

    function test_NonAdminCannotSetWETHPriceInUSD() public {
        vm.startPrank(nonAdmin);
        vm.expectRevert("Caller is not an admin");
        priceOracle.setWETHPriceInUSD(3000 * 10 ** 18);
        vm.stopPrank();
    }

    function test_NonAdminCannotAddAdmin() public {
        vm.startPrank(nonAdmin);
        vm.expectRevert("Ownable: caller is not the owner");
        priceOracle.addAdmin(nonAdmin);
        vm.stopPrank();
    }

    function test_NonAdminCannotRemoveAdmin() public {
        vm.startPrank(nonAdmin);
        vm.expectRevert("Ownable: caller is not the owner");
        priceOracle.removeAdmin(admin);
        vm.stopPrank();
    }
}
