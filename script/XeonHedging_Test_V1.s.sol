// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "@forge-std/Script.sol";
import {XeonHedging_Test_V1} from "../src/XeonHedging_Test_V1.sol";

// base sepolia
// simulate: forge script script/XeonHedging_Test_V1.s.sol:XeonHedgingScript --rpc-url $BASE_SEPOLIA_RPC_URL --chain-id 84532 -vvvv
// broadcast: forge script script/XeonHedging_Test_V1.s.sol:XeonHedgingScript --rpc-url $BASE_SEPOLIA_RPC_URL --chain-id 84532 -vv --broadcast --verify

contract XeonHedgingScript is Script {
    address public deployer = 0x56557c3266d11541c2D939BF6C05BFD29e881e55;
    address public priceOracle = 0xCDeA17068968A1A989a0D21E28c5c61fF220fe7E;
    address public stakingContract = 0x56557c3266d11541c2D939BF6C05BFD29e881e55; // todo: replace with actual address once deployed

    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        console2.log("Deploying XeonHedging contract...");

        XeonHedging_Test_V1 xeonHedging = new XeonHedging_Test_V1(priceOracle, stakingContract);

        console2.log("XeonHedging deployed at:", address(xeonHedging));

        vm.stopBroadcast();
    }
}
