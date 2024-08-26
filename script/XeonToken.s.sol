// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "@forge-std/Script.sol";
import {XeonToken} from "../src/XeonToken.sol";
import {XeonTokenDistributor} from "../src/XeonTokenDistributor.sol";

// base sepolia
// simulate: forge script script/XeonToken.s.sol:XeonTokenScript --rpc-url $BASE_SEPOLIA_RPC_URL --chain-id 84532 -vvvv
// broadcast: forge script script/XeonToken.s.sol:XeonTokenScript --rpc-url $BASE_SEPOLIA_RPC_URL --chain-id 84532 -vv --broadcast --verify
contract XeonTokenScript is Script {
    address public deployer = 0x56557c3266d11541c2D939BF6C05BFD29e881e55;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // Deploy XeonToken contract
        console2.log("Deploying XeonToken contract...");
        XeonToken xeonToken = new XeonToken();
        console2.log("XeonToken deployed at:", address(xeonToken));

        // Deploy XeonTokenDistributor contract with XeonToken instance
        console2.log("Deploying XeonTokenDistributor contract...");
        XeonTokenDistributor xeonTokenDistributor = new XeonTokenDistributor(xeonToken);
        console2.log("XeonTokenDistributor deployed at:", address(xeonTokenDistributor));

        // Distribute initial supply
        uint256 distributorSupply = 70_000_000 * 10 ** xeonToken.decimals();
        uint256 deployerSupply = 30_000_000 * 10 ** xeonToken.decimals();

        console2.log("Transferring 70m XEON to XeonTokenDistributor...");
        xeonToken.transfer(address(xeonTokenDistributor), distributorSupply);

        console2.log("Transferring 30m XEON to deployer...");
        xeonToken.transfer(deployer, deployerSupply);

        vm.stopBroadcast();
    }
}
