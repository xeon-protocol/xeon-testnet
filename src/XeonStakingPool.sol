// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/**
 * @title XeonStaking
 * @dev Allows users to stake XEON tokens, minting an equal amount of stXEON
 * which are used internally in the staking pool to distribute rewards and
 * vote on protocol revenue and token buybacks.
 *
 * @notice this is a testnet version of XeonStaking and should not be used in production
 * @author Jon Bray <jon@xeon-protocol.io>
 */
contract XeonStakingPool is ERC20, Ownable {
    using SafeERC20 for IERC20;

    //========== ADDRESS VARIABLES ==========//
    // XEON address
    IERC20 public immutable XEON;
    // WETH address
    IWETH public immutable WETH;
    // Xeon Protocol team multi-sig
    address public teamAddress;
    // destination for XEON tokens bought back by the staking pool
    address public constant buybackDestination = teamAddress;

    // Uniswap router for swaps
    IUniswapV2Router02 public immutable uniswapV2Router;
    ISwapRouter public immutable uniswapV3Router;

    //========== EPOCH CONSTANTS ==========//
    /* todo: for mainnet, update to 30 day epochs + 3 day unlock */
    uint256 public epoch = 1; // skip epoch 0
    uint256 public constant EPOCH_DURATION = 3 days;
    uint256 public constant UNLOCK_PERIOD = 2 days;
    uint256 public nextEpochStart;
    bool public isPoolLocked;

    //========== REWARD DISTRIBUTION CONSTANTS ==========//
    uint256 public constant teamPercentage = 5;
    uint256 public constant buyBackPercentage = 5;

    //========== MAPPINGS ==========//
    mapping(address => uint256) public stakedAmounts;

    //========== EVENTS ==========//
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsDistributed(uint256 teamReward, uint256 buyBackAmount, uint256 stakersReward);
    event TokenSwapped(address indexed token, uint256 amount, uint256 wethReceived);
    event PoolLocked(uint256 epoch, uint256 timestamp);
    event PoolUnlocked(uint256 epoch, uint256 timestamp);

    constructor(
        IERC20 _XEON,
        IWETH _WETH,
        IUniswapV2Router02 _uniswapV2Router,
        ISwapRouter _uniswapV3Router,
        address _teamAddress
    ) ERC20("Staked XEON", "stXEON") {
        XEON = _XEON;
        WETH = _WETH;
        uniswapV2Router = _uniswapV2Router;
        uniswapV3Router = _uniswapV3Router;
        teamAddress = _teamAddress;

        /* todo: for mainnet, start in a locked state and pre-allocate XEON */
        isPoolLocked = false;
        nextEpochStart = block.timestamp + EPOCH_DURATION;
    }

    //========== STAKING FUNCTIONS ==========//
    /**
     * @dev Stake XEON tokens into the pool
     * @param amount of XEON tokens to stake
     */
    function stake(uint256 amount) external {
        require(!isPoolLocked, "Staking is locked");
        require(amount > 0, "Cannot stake 0 tokens");

        XEON.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);

        stakedAmounts[msg.sender] += amount;
        emit Staked(msg.sender, amount);
    }

    /**
     * @dev Unstake XEON tokens from the pool
     * @notice tokens can only be unstaked when the pool is unlocked.
     * @param amount of XEON tokens to unstake
     */
    function unstake(uint256 amount) external {
        require(!isPoolLocked, "Unstaking is locked");
        require(amount > 0, "Cannot unstake 0 tokens");
        require(balanceOf(msg.sender) >= amount, "Insufficient staked balance");

        _burn(msg.sender, amount);
        stakedAmounts[msg.sender] -= amount;

        XEON.safeTransfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    //========== EPOCH MANAGEMENT ==========//
    function checkEpoch() external {
        if (block.timestamp >= nextEpochStart) {
            if (isPoolLocked) {
                _unlockPool();
            } else {
                _lockPool();
            }
        }
    }

    // internal function to lock the pool and start a new epoch
    function _lockPool() internal {
        isPoolLocked = true;
        nextEpochStart = block.timestamp + UNLOCK_PERIOD;
        emit PoolLocked(epoch, block.timestamp);
    }

    // internal function to unlock the pool
    function _unlockPool() internal {
        isPoolLocked = false;
        epoch++;
        nextEpochStart = block.timestamp + EPOCH_DURATION;
        autoWithdrawRewards(); // Distribute rewards at the start of the new epoch
        emit PoolUnlocked(epoch, block.timestamp);
    }

    //========== REWARD DISTRIBUTION==========//
    function autoWithdrawRewards() internal {
        uint256 totalWETH = WETH.balanceOf(address(this));
        uint256 teamReward = (totalWETH * teamPercentage) / 100;
        uint256 buyBackAmount = (totalWETH * buyBackPercentage) / 100;
        uint256 stakersReward = totalWETH - teamReward - buyBackAmount;

        // Distribute WETH
        WETH.transfer(teamAddress, teamReward);
        WETH.transfer(buybackDestination, buyBackAmount);

        // Distribute to stakers
        uint256 totalSupply = totalSupply();
        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            uint256 reward = (stakedAmounts[staker] * stakersReward) / totalSupply;
            WETH.transfer(staker, reward);
        }

        emit RewardsDistributed(teamReward, buyBackAmount, stakersReward);
    }

    // Owner can trigger rewards distribution at any time
    function withdrawRewards() external onlyOwner {
        autoWithdrawRewards();
    }

    // Swap ERC20 tokens to WETH
    function swapTokenToWETH(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Approve the Uniswap router to spend the tokens
        IERC20(token).approve(address(uniswapV2Router), amount);

        address;
        path[0] = token;
        path[1] = address(WETH);

        uint256[] memory amounts = uniswapV2Router.swapExactTokensForTokens(
            amount,
            0, // Accept any amount of WETH
            path,
            address(this),
            block.timestamp
        );

        emit TokenSwapped(token, amount, amounts[1]);
    }
}
