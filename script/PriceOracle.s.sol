// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "@forge-std/Script.sol";
import {PriceOracle} from "../src/PriceOracle.sol";

contract PriceOracleScript is Script {
    address public deployer = 0x56557c3266d11541c2D939BF6C05BFD29e881e55;

    // base sepolia
    // simulate: forge script script/PriceOracle.s.sol:PriceOracleScript --rpc-url $BASE_SEPOLIA_RPC_URL --chain-id 84532 -vvvv
    // broadcast: forge script script/PriceOracle.s.sol:PriceOracleScript --rpc-url $BASE_SEPOLIA_RPC_URL --chain-id 84532 -vv --broadcast --verify

    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        console2.log("deploying PriceOracle contract...");
        PriceOracle priceOracle = new PriceOracle();

        console2.log("PriceOracle deployed at:", address(priceOracle));

        vm.stopBroadcast();
    }
}
