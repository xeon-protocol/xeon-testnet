// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "@forge-std/Script.sol";
import {MockERC20, MockERC20Factory, MockWETH} from "../src/MockERC20Factory.sol";
import {OnboardingUtils} from "../src/OnboardingUtils.sol";


contract OnboardingScript is Script {
    address public deployer = 0x56557c3266d11541c2D939BF6C05BFD29e881e55;

    address[] public admin = [
        0xFc09CA87a0E58C8d9e01bC3060CBEB60Ad434cd4,
        0x212dB369d8C032c3D319e2136eA85F34742Ea399,
        0x5Fb8EfD425C3eBB85C0773CE33820abC28d1b858
    ];

    // base sepolia
    // simulate: forge script script/Onboarding.s.sol:OnboardingScript --rpc-url $BASE_SEPOLIA_RPC_URL --chain-id 84532 -vvvv
    // broadcast: forge script script/Onboarding.s.sol:OnboardingScript --rpc-url $BASE_SEPOLIA_RPC_URL --chain-id 84532 -vv --broadcast --verify

    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        console2.log("deploying MockERC20Factory contract...");
        MockERC20Factory tokenFactory = new MockERC20Factory();

        console2.log("deploying OnboardingUtils contract...");
        address wethAddress = tokenFactory.deployMockWETH(0);
        OnboardingUtils onboardingUtils = new OnboardingUtils(tokenFactory, wethAddress);

        console2.log("adding admin accounts to token factory...");
        for (uint256 i = 0; i < admin.length; i++) {
            tokenFactory.addAdmin(admin[i]);
        }

        console2.log("adding admin accounts to onboarding utils...");
        for (uint256 i = 0; i < admin.length; i++) {
            onboardingUtils.addAdmin(admin[i]);
        }

        deployToken(tokenFactory, onboardingUtils, "Vela Exchange", "oVELA");
        deployToken(tokenFactory, onboardingUtils, "Pepe", "oPEPE");
        deployToken(tokenFactory, onboardingUtils, "Degen", "oDEGEN");
        deployToken(tokenFactory, onboardingUtils, "Higher", "oHIGHER");
        deployToken(tokenFactory, onboardingUtils, "Rorschach", "oROR");

        logDeployedTokens(tokenFactory);

        vm.stopBroadcast();
    }

    function deployToken(
        MockERC20Factory tokenFactory,
        OnboardingUtils onboardingUtils,
        string memory name,
        string memory symbol
    ) internal {
        console2.log(string(abi.encodePacked("deploying token: ", name, " (", symbol, ")")));
        address tokenAddress = tokenFactory.deploy(name, symbol, 18, 0);
        MockERC20 token = MockERC20(tokenAddress);
        token.grantRole(token.MINTER_ROLE(), address(onboardingUtils));
    }

    function logDeployedTokens(MockERC20Factory tokenFactory) internal view {
        MockERC20Factory.TokenInfo[] memory tokens = tokenFactory.getDeployedTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            console2.log("Token Name:", tokens[i].name);
            console2.log("Token Symbol:", tokens[i].symbol);
            console2.log("Token Address:", tokens[i].tokenAddress);
        }
    }
}
