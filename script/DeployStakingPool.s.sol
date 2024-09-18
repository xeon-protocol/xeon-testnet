// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from "@forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {XeonStakingPool} from "../src/XeonStakingPool.sol";

contract DeployStakingPool is Script {
    // Sepolia testnet addresses (provided in comments)
    address public XEON = 0x296dBB55cbA3c9beA7A8ac171542bEEf2ceD1163;
    address public WETH = 0x395cB7753B02A15ed1C099DFc36bF00171F18218;
    address public UNISWAP_V2_ROUTER = 0x1689E7B1F10000AE47eBfE339a4f69dECd19F602;
    address public UNISWAP_V3_ROUTER = 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4;
    address public TEAM_ADDRESS = 0x56557c3266d11541c2D939BF6C05BFD29e881e55;

    // base sepolia
    // simulate: forge script script/DeployStakingPool.s.sol:DeployStakingPool --rpc-url $BASE_SEPOLIA_RPC_URL --chain-id 84532 -vvvv
    // broadcast: forge script script/DeployStakingPool.s.sol:DeployStakingPool --rpc-url $BASE_SEPOLIA_RPC_URL --chain-id 84532 -vv --broadcast --verify

    function run() external {
        // Start broadcasting the transaction using the deployer's private key
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // Deploy the XeonStakingPool contract with constructor parameters
        XeonStakingPool xeonStakingPool = new XeonStakingPool(
            IERC20(XEON),
            IERC20(WETH),
            IUniswapV2Router02(UNISWAP_V2_ROUTER),
            ISwapRouter(UNISWAP_V3_ROUTER),
            TEAM_ADDRESS
        );

        // Log the address of the deployed contract
        console2.log("XeonStakingPool deployed at:", address(xeonStakingPool));

        // Stop broadcasting the transaction
        vm.stopBroadcast();
    }
}

contract UpdateOwner is Script {
    address public NEW_OWNER = 0x56557c3266d11541c2D939BF6C05BFD29e881e55;
    address public XEON_STAKING = 0x949B2156916A63686835DaF66518C22D497bf8B0;

    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        XeonStakingPool(XEON_STAKING).transferOwnership(NEW_OWNER);
        vm.stopBroadcast();
    }
}
