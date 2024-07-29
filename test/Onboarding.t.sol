// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "@forge-std/Test.sol";
import {console2} from "@forge-std/console2.sol";
import {MockERC20, MockERC20Factory, MockWETH} from "../src/MockERC20Factory.sol";
import {OnboardingUtils} from "../src/OnboardingUtils.sol";

contract OnboardingTest is Test {
    MockERC20Factory public mockERC20Factory;
    OnboardingUtils public onboardingUtils;
    MockERC20 public mockERC20;
    MockWETH public wethToken;
    address public deployer = address(this);
    address public admin = address(0x1);
    address public nonAdmin = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);

    function setUp() public {
        console2.log("Setting up the environment...");

        // Deploy MockERC20Factory contract
        mockERC20Factory = new MockERC20Factory();
        console2.log("Deployed MockERC20Factory contract");

        // Grant deployer default admin role
        mockERC20Factory.grantRole(mockERC20Factory.DEFAULT_ADMIN_ROLE(), deployer);
        console2.log("Granted DEFAULT_ADMIN_ROLE to deployer");

        // Deploy WETH token
        address wethTokenAddress = mockERC20Factory.deploy("Wrapped Ether", "WETH", 18, 0);
        wethToken = MockWETH(wethTokenAddress);
        console2.log("Deployed WETH token at:", wethTokenAddress);

        // Deploy OnboardingUtils contract
        onboardingUtils = new OnboardingUtils(mockERC20Factory, wethTokenAddress);
        console2.log("Initialized OnboardingUtils with MockERC20Factory and WETH address");

        // Grant admin roles
        vm.startPrank(deployer);
        mockERC20Factory.addAdmin(admin);
        mockERC20Factory.grantRole(mockERC20Factory.DEFAULT_ADMIN_ROLE(), admin);
        onboardingUtils.addAdmin(admin);
        onboardingUtils.grantRole(onboardingUtils.DEFAULT_ADMIN_ROLE(), admin);
        console2.log("Granted roles to admin in both contracts");

        // Deploy ERC20 token
        address tokenAddress = mockERC20Factory.deploy("MockToken", "MTK", 18, 0);
        mockERC20 = MockERC20(tokenAddress);
        console2.log("Deployed MockERC20 token at:", tokenAddress);

        // Grant minter role to OnboardingUtils for all tokens
        mockERC20.grantRole(mockERC20.MINTER_ROLE(), address(onboardingUtils));
        wethToken.grantRole(wethToken.MINTER_ROLE(), address(onboardingUtils));
        console2.log("Granted MINTER_ROLE to OnboardingUtils for MockToken and WETH");

        vm.stopPrank();
    }

    function test_claimInitial() public {
        console2.log("Testing user claiming initial tokens without referral...");
        vm.startPrank(user2);
        console2.log("Current account:", user2);
        onboardingUtils.claimInitial(address(mockERC20));
        uint256 expectedBalance = 100_000 * 10 ** 18;
        uint256 actualBalance = mockERC20.balanceOf(user2);
        console2.log("Expected balance:", expectedBalance);
        console2.log("Actual balance:", actualBalance);
        assertEq(expectedBalance, actualBalance, "User2 balance should be 100_000 MTK after initial claim");

        uint256 expectedWETHBalance = 1 * 10 ** 18;
        uint256 actualWETHBalance = wethToken.balanceOf(user2);
        console2.log("Expected WETH balance:", expectedWETHBalance);
        console2.log("Actual WETH balance:", actualWETHBalance);
        assertEq(expectedWETHBalance, actualWETHBalance, "User2 balance should be 1 WETH after initial claim");

        vm.stopPrank();
    }

    function test_claimInitialWithReferral() public {
        console2.log("Testing user claiming initial tokens with referral...");

        vm.startPrank(user1);
        console2.log("Current account:", user1);
        onboardingUtils.claimInitialWithReferral(address(mockERC20), admin);
        uint256 expectedUserBalance = 110_000 * 10 ** 18; // 100,000 initial + 10,000 referral bonus
        uint256 actualUserBalance = mockERC20.balanceOf(user1);
        console2.log("Expected user balance:", expectedUserBalance);
        console2.log("Actual user balance:", actualUserBalance);
        assertEq(
            expectedUserBalance,
            actualUserBalance,
            "User1 balance should be 110_000 MTK after initial claim with referral"
        );

        uint256 expectedWETHBalance = 1 * 10 ** 18;
        uint256 actualWETHBalance = wethToken.balanceOf(user1);
        console2.log("Expected WETH balance:", expectedWETHBalance);
        console2.log("Actual WETH balance:", actualWETHBalance);
        assertEq(expectedWETHBalance, actualWETHBalance, "User1 balance should be 1 WETH after initial claim");

        vm.stopPrank();

        vm.startPrank(admin);
        console2.log("Current account:", admin);
        uint256 expectedAdminBalance = 10_000 * 10 ** 18; // 10,000 referral bonus
        uint256 actualAdminBalance = mockERC20.balanceOf(admin);
        console2.log("Expected admin balance:", expectedAdminBalance);
        console2.log("Actual admin balance:", actualAdminBalance);
        assertEq(expectedAdminBalance, actualAdminBalance, "Admin balance should be 10_000 MTK as referral bonus");
        vm.stopPrank();
    }

    function test_claimInitialAlreadyClaimed() public {
        console2.log("Testing user trying to claim initial tokens after already claiming...");
        vm.startPrank(user1);
        console2.log("Current account:", user1);
        onboardingUtils.claimInitial(address(mockERC20));
        vm.expectRevert("OnboardingUtils: Already claimed initial tokens");
        onboardingUtils.claimInitial(address(mockERC20));
        vm.stopPrank();
    }

    function test_claimTokens() public {
        address newUser = address(0x5);
        console2.log("Testing claiming tokens once per week for a new user...");

        vm.startPrank(newUser);
        console2.log("Current account:", newUser);
        vm.expectRevert("OnboardingUtils: Must perform initial claim first");
        onboardingUtils.claimTokens(address(mockERC20));
        vm.stopPrank();

        vm.startPrank(newUser);
        console2.log("Performing initial claim for newUser");
        onboardingUtils.claimInitial(address(mockERC20));
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);

        vm.startPrank(newUser);
        console2.log("Claiming tokens after initial claim for newUser");
        onboardingUtils.claimTokens(address(mockERC20));
        uint256 expectedBalance = 110_000 * 10 ** 18;
        uint256 actualBalance = mockERC20.balanceOf(newUser);
        console2.log("Expected balance:", expectedBalance);
        console2.log("Actual balance:", actualBalance);
        assertEq(expectedBalance, actualBalance, "newUser balance should be 110_000 MTK after claiming tokens");
        vm.stopPrank();

        vm.startPrank(newUser);
        console2.log("Attempting to claim again immediately, expecting a revert");
        vm.expectRevert("OnboardingUtils: Claim only allowed once per week");
        onboardingUtils.claimTokens(address(mockERC20));
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);

        vm.startPrank(newUser);
        console2.log("Claiming tokens again after one week for newUser");
        onboardingUtils.claimTokens(address(mockERC20));
        uint256 newExpectedBalance = 120_000 * 10 ** 18;
        uint256 newActualBalance = mockERC20.balanceOf(newUser);
        console2.log("New expected balance:", newExpectedBalance);
        console2.log("New actual balance:", newActualBalance);
        assertEq(
            newExpectedBalance, newActualBalance, "newUser balance should be 120_000 MTK after claiming tokens again"
        );
        vm.stopPrank();
    }

    /**
     * @notice test getting tokens
     */
    function test_getTokens() public {
        console2.log("Testing get tokens...");
        vm.startPrank(admin);
        console2.log("Current account:", admin);

        // Deploy one additional token
        address tokenAddress1 = mockERC20Factory.deploy("TestToken1", "TTK1", 18, 1_000_000 * 10 ** 18);
        console2.log("Token1 deployed at:", tokenAddress1);

        // Get all deployed tokens
        MockERC20Factory.TokenInfo[] memory tokens = mockERC20Factory.getDeployedTokens();
        console2.log("Number of tokens:", tokens.length);
        assertEq(tokens.length, 3, "There should be 3 tokens");

        // Assertions for the WETH token
        console2.log("Token 1 address:", tokens[0].tokenAddress);
        console2.log("Token 1 name:", tokens[0].name);
        console2.log("Token 1 symbol:", tokens[0].symbol);
        console2.log("Token 1 decimals:", tokens[0].decimals);
        console2.log("Token 1 total supply:", tokens[0].totalSupply);
        assertEq(tokens[0].tokenAddress, address(wethToken), "First token address should match the WETH token");
        assertEq(tokens[0].name, "Wrapped Ether", "First token name should be 'Wrapped Ether'");
        assertEq(tokens[0].symbol, "WETH", "First token symbol should be 'WETH'");
        assertEq(tokens[0].decimals, 18, "First token decimals should be 18");
        assertEq(tokens[0].totalSupply, 0, "First token total supply should be 0");

        // Assertions for the setup token
        console2.log("Token 2 address:", tokens[1].tokenAddress);
        console2.log("Token 2 name:", tokens[1].name);
        console2.log("Token 2 symbol:", tokens[1].symbol);
        console2.log("Token 2 decimals:", tokens[1].decimals);
        console2.log("Token 2 total supply:", tokens[1].totalSupply);
        assertEq(tokens[1].tokenAddress, address(mockERC20), "Second token address should match the setup token");
        assertEq(tokens[1].name, "MockToken", "Second token name should be 'MockToken'");
        assertEq(tokens[1].symbol, "MTK", "Second token symbol should be 'MTK'");
        assertEq(tokens[1].decimals, 18, "Second token decimals should be 18");
        assertEq(tokens[1].totalSupply, 0, "Second token total supply should be 0");

        // Assertions for the newly deployed token
        console2.log("Token 3 address:", tokens[2].tokenAddress);
        console2.log("Token 3 name:", tokens[2].name);
        console2.log("Token 3 symbol:", tokens[2].symbol);
        console2.log("Token 3 decimals:", tokens[2].decimals);
        console2.log("Token 3 total supply:", tokens[2].totalSupply);
        assertEq(tokens[2].tokenAddress, tokenAddress1, "Third token address should match");
        assertEq(tokens[2].name, "TestToken1", "Third token name should be 'TestToken1'");
        assertEq(tokens[2].symbol, "TTK1", "Third token symbol should be 'TTK1'");
        assertEq(tokens[2].decimals, 18, "Third token decimals should be 18");
        assertEq(tokens[2].totalSupply, 1_000_000 * 10 ** 18, "Third token total supply should be 1_000_000 TTK1");

        vm.stopPrank();
    }

    function test_getterMethods() public {
        console2.log("Testing getter methods...");

        vm.startPrank(user1);
        onboardingUtils.claimInitialWithReferral(address(mockERC20), admin);
        vm.stopPrank();

        vm.startPrank(user2);
        onboardingUtils.claimInitialWithReferral(address(mockERC20), user1);
        vm.stopPrank();

        address[] memory referrals = onboardingUtils.getReferralsBy(user1);
        console2.log("Number of referrals by user1:", referrals.length);
        assertEq(referrals.length, 1, "User1 should have 1 referral");
        console2.log("User1's referral:", referrals[0]);
        assertEq(referrals[0], user2, "User1's referral should be User2");

        address referrer = onboardingUtils.getReferrerOf(user2);
        console2.log("User2's referrer:", referrer);
        assertEq(referrer, user1, "User2's referrer should be User1");

        bool hasClaimed = onboardingUtils.hasUserClaimedInitial(user1);
        console2.log("User1 has claimed initial tokens:", hasClaimed);
        assertTrue(hasClaimed, "User1 should have claimed initial tokens");

        hasClaimed = onboardingUtils.hasUserClaimedInitial(user2);
        console2.log("User2 has claimed initial tokens:", hasClaimed);
        assertTrue(hasClaimed, "User2 should have claimed initial tokens");

        uint256 referralCount = onboardingUtils.getReferralCount(user1);
        console2.log("User1's referral count:", referralCount);
        assertEq(referralCount, 1, "User1 should have 1 referral");
    }
}
