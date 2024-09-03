// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./types/XeonVoting.sol";

/**
 * @title XeonStakingPool
 * @dev Allows users to stake XEON tokens, minting an equal amount of non-transferable stXEON tokens.
 * stXEON represents the user's share in the staking pool and is used for reward distribution.
 *
 * @notice This is a testnet version of XeonStaking and should not be used in production.
 * @author Jon Bray <jon@xeon-protocol.io>
 */
contract XeonStakingPool is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    //========== ADDRESS VARIABLES ==========//
    IERC20 public XEON;
    IERC20 public WETH;
    XeonVoting public votingContract;
    address public teamAddress;
    address[] public stakers;

    IUniswapV2Router02 public immutable uniswapV2Router;
    ISwapRouter public immutable uniswapV3Router;

    //========== EPOCH VARIABLES ==========//
    uint64 public nextEpochStart;
    uint64 public constant EPOCH_DURATION = 3 days; // mainnet: 30 days
    uint64 public constant UNLOCK_PERIOD = 2 days; // mainnet: 3 days
    uint128 public epoch = 0; // start at 0 if pool starts in unlocked state
    bool public isPoolLocked;

    //========== REWARD VARIABLES ==========//
    uint8 public teamPercentage = 5;

    //========== MAPPINGS ==========//
    mapping(address => uint256) public stakedAmounts;
    mapping(address => uint256) public stakerPercentage;

    //========== EVENTS ==========//
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsDistributed(uint256 teamReward, uint256 buyBackAmount, uint256 stakersReward);
    event TokenSwapped(address indexed token, uint256 amount, uint256 wethReceived);
    event PoolLocked(uint256 epoch, uint256 timestamp);
    event PoolUnlocked(uint256 epoch, uint256 timestamp);
    event TeamPercentageUpdated(uint256 newPercentage);

    /**
     * @notice constructor to initialize the staking pool
     * @param _XEON address of XEON token
     * @param _WETH address of WETH token
     * @param _uniswapV2Router address of the Uniswap V2 Router
     * @param _uniswapV3Router address of the Uniswap V3 Router
     * @param _votingContract address of the voting contract
     * @param _teamAddress address of the team ecosystem multisig
     */
    constructor(
        IERC20 _XEON,
        IERC20 _WETH,
        IUniswapV2Router02 _uniswapV2Router,
        ISwapRouter _uniswapV3Router,
        XeonVoting _votingContract,
        address _teamAddress
    ) ERC20("Staked XEON", "stXEON") Ownable(msg.sender) {
        XEON = _XEON;
        WETH = _WETH;
        uniswapV2Router = _uniswapV2Router;
        uniswapV3Router = _uniswapV3Router;
        votingContract = _votingContract;
        teamAddress = _teamAddress;

        isPoolLocked = false; // Start in an unlocked state
        nextEpochStart = uint64(block.timestamp) + UNLOCK_PERIOD; // Epoch 1 starts after the unlock period
    }

    //========== MODIFIERS ==========//

    modifier isStaker() {
        require(balanceOf(msg.sender) > 0, "Address is not a staker");
        _;
    }

    modifier whenUnlocked() {
        require(!isPoolLocked, "Staking/Unstaking is locked during the staking period.");
        _;
    }

    modifier whenLocked() {
        require(isPoolLocked, "Cannot perform this action while the pool is unlocked.");
        _;
    }

    /**
     * @dev Restricts stXEON transfers. stXEON can only be minted/burned by this contract.
     */
    function _transfer(address, address, uint256) internal pure override {
        revert("stXEON is non-transferable");
    }

    //========== STAKING FUNCTIONS ==========//

    function stake(uint256 amount) external whenUnlocked {
        require(amount > 0, "Cannot stake 0 tokens");

        XEON.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);

        if (stakedAmounts[msg.sender] == 0) {
            stakers.push(msg.sender);
        }

        stakedAmounts[msg.sender] += amount;

        _updateStakerPercentage(msg.sender);

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external whenUnlocked isStaker {
        require(amount > 0, "Cannot unstake 0 tokens");
        require(balanceOf(msg.sender) >= amount, "Insufficient staked balance");

        _burn(msg.sender, amount);
        stakedAmounts[msg.sender] -= amount;

        if (stakedAmounts[msg.sender] == 0) {
            _removeStaker(msg.sender);
        }

        _updateStakerPercentage(msg.sender);

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

    function _lockPool() internal whenUnlocked {
        isPoolLocked = true;

        uint8 newBuybackPercentage = votingContract.calculateNewBuybackPercentage(totalSupply());
        votingContract.updateBuybackPercentage(newBuybackPercentage);

        nextEpochStart = block.timestamp + EPOCH_DURATION + UNLOCK_PERIOD;
        epoch++;

        emit PoolLocked(epoch, block.timestamp);
    }

    function _unlockPool() internal whenLocked {
        isPoolLocked = false;

        nextEpochStart = block.timestamp + UNLOCK_PERIOD;

        _autoWithdrawRewards();
        _swapWETHForXEON();

        emit PoolUnlocked(epoch, block.timestamp);
    }

    //========== REWARD DISTRIBUTION==========//

    function _autoWithdrawRewards() internal nonReentrant {
        uint256 totalWETH = WETH.balanceOf(address(this));
        uint256 teamReward = (totalWETH * teamPercentage) / 100;
        uint256 buyBackPercentage = votingContract.buyBackPercentage(); // Fetch from the voting contract
        uint256 buyBackAmount = (totalWETH * buyBackPercentage) / 100;
        uint256 stakersReward = totalWETH - teamReward - buyBackAmount;

        WETH.transfer(teamAddress, teamReward);
        WETH.transfer(teamAddress, buyBackAmount);

        uint256 totalStakedSupply = totalSupply();
        uint256 stakersLength = stakers.length;
        for (uint256 i = 0; i < stakersLength; i++) {
            address staker = stakers[i];
            uint256 reward = (stakedAmounts[staker] * stakersReward) / totalStakedSupply;
            WETH.transfer(staker, reward);
        }

        emit RewardsDistributed(teamReward, buyBackAmount, stakersReward);
    }

    function withdrawRewards() external onlyOwner {
        _autoWithdrawRewards();
    }

    function swapTokenToWETH(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        IERC20(token).approve(address(uniswapV2Router), amount);

        address[] memory path = new address[](2);
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

    //========== POOL VOTING ==========//

    function voteForBuybackPercentage(uint8 percentage) external isStaker whenUnlocked {
        uint256 stakedBalance = balanceOf(msg.sender);
        uint256 totalStaked = totalSupply();

        votingContract.voteForBuybackPercentage(stakedBalance, totalStaked, percentage);
    }

    //========== INTERNAL FUNCTIONS ==========//

    function _updateStakerPercentage(address staker) internal {
        uint256 totalStaked = totalSupply();
        if (totalStaked > 0) {
            stakerPercentage[staker] = (stakedAmounts[staker] * 100) / totalStaked;
        } else {
            stakerPercentage[staker] = 0;
        }
    }

    function _removeStaker(address staker) internal {
        uint256 length = stakers.length;
        for (uint256 i = 0; i < length; i++) {
            if (stakers[i] == staker) {
                stakers[i] = stakers[length - 1];
                stakers.pop();
                break;
            }
        }
    }

    function _swapWETHForXEON() internal {
        uint256 totalWETH = WETH.balanceOf(address(this));
        uint256 buyBackPercentage = votingContract.buyBackPercentage(); // Fetch from the voting contract
        uint256 amountToSwap = (totalWETH * buyBackPercentage) / 100;

        WETH.approve(address(uniswapV2Router), amountToSwap);

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(XEON);

        uint256[] memory amounts = uniswapV2Router.swapExactTokensForTokens(
            amountToSwap,
            0, // accept any amount of XEON
            path,
            address(this),
            block.timestamp + 5 minutes
        );

        emit TokenSwapped(address(WETH), amountToSwap, amounts[1]);
    }

    //========== OWNER FUNCTIONS ==========//

    function setTeamPercentage(uint256 newPercentage) external onlyOwner {
        require(newPercentage < 100, "Percentage must be less than 100");
        teamPercentage = uint8(newPercentage);
        emit TeamPercentageUpdated(newPercentage);
    }

    function updateXEONAddress(IERC20 _newXEON) external onlyOwner {
        require(address(_newXEON) != address(0), "Invalid address");
        XEON = _newXEON;
    }

    function updateWETHAddress(IERC20 _newWETH) external onlyOwner {
        require(address(_newWETH) != address(0), "Invalid address");
        WETH = _newWETH;
    }
}
