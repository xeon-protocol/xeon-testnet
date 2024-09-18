// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "@forge-std/Script.sol";
import {PriceOracle} from "../src/PriceOracle.sol";

// base sepolia
// simulate: forge script script/PriceOracle.s.sol:DeployPriceOracleScript --rpc-url $BASE_SEPOLIA_RPC_URL --chain-id 84532 -vvvv
// broadcast: forge script script/PriceOracle.s.sol:DeployPriceOracleScript --rpc-url $BASE_SEPOLIA_RPC_URL --chain-id 84532 -vv --broadcast --verify
contract DeployPriceOracleScript is Script {
    address public deployer = 0x56557c3266d11541c2D939BF6C05BFD29e881e55;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        console2.log("deploying PriceOracle contract...");
        PriceOracle priceOracle = new PriceOracle();

        console2.log("PriceOracle deployed at:", address(priceOracle));

        vm.stopBroadcast();
    }
}

// base sepolia
// simulate: forge script script/PriceOracle.s.sol:UpdatePricesScript --rpc-url $BASE_SEPOLIA_RPC_URL --chain-id 84532 -vvvv
// broadcast: forge script script/PriceOracle.s.sol:UpdatePricesScript --rpc-url $BASE_SEPOLIA_RPC_URL --chain-id 84532 -vv --broadcast --verify
contract UpdatePricesScript is Script {
    address public priceOracleAddress = 0xCDeA17068968A1A989a0D21E28c5c61fF220fe7E;
    address public deployer = 0x56557c3266d11541c2D939BF6C05BFD29e881e55;

    // Token prices in WETH
    uint256 public oVELAPrice = 0.0000725 * 10 ** 18;
    uint256 public oPEPEPrice = 0.00000031 * 10 ** 18;
    uint256 public oDEGENPrice = 0.0000252 * 10 ** 18;
    uint256 public oHIGHERPrice = 0.00000469 * 10 ** 18;
    uint256 public oRORPrice = 0.000225 * 10 ** 18;

    // WETH price in USD
    uint256 public WETHPriceInUSD = 2500 * 10 ** 18;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        PriceOracle priceOracle = PriceOracle(priceOracleAddress);

        console2.log("Updating prices in PriceOracle contract...");

        priceOracle.setTokenPriceInWETH(priceOracle.oVELA(), oVELAPrice);
        priceOracle.setTokenPriceInWETH(priceOracle.oPEPE(), oPEPEPrice);
        priceOracle.setTokenPriceInWETH(priceOracle.oDEGEN(), oDEGENPrice);
        priceOracle.setTokenPriceInWETH(priceOracle.oHIGHER(), oHIGHERPrice);
        priceOracle.setTokenPriceInWETH(priceOracle.oROR(), oRORPrice);
        priceOracle.setWETHPriceInUSD(WETHPriceInUSD);

        console2.log("Prices updated successfully.");

        vm.stopBroadcast();
    }
}
