// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/**
 * @title XeonStakingPool
 * @dev Allows users to stake XEON tokens, minting an equal amount of non-transferable stXEON tokens.
 * stXEON represents the user's share in the staking pool and is used for reward distribution.
 *
 * @notice This is a testnet version of XeonStaking and should not be used in production.
 * @author Jon Bray <jon@xeon-protocol.io>
 */
contract XeonStakingPool is ERC20, Ownable, ReentrancyGuard {
    /* todo: separate voting logic into XeonVoting contract, which reads staker data from this contract and returns vote results for buyBackPercentage */
    using SafeERC20 for IERC20;

    //========== ADDRESS VARIABLES ==========//
    IERC20 public XEON;
    IERC20 public WETH;
    address public teamAddress;
    address[] public stakers;

    IUniswapV2Router02 public immutable uniswapV2Router;
    ISwapRouter public immutable uniswapV3Router;

    //========== EPOCH VARIABLES ==========//
    /* todo: update constants for mainnet */
    uint64 public nextEpochStart;
    uint64 public constant EPOCH_DURATION = 30 days; // mainnet: 30 days
    uint64 public constant UNLOCK_PERIOD = 2 days; // mainnet: 3 days
    uint128 public epoch = 0; // start at 0 if pool starts in unlocked state
    bool public isPoolLocked;

    //========== REWARD VARIABLES ==========//
    uint8 public teamPercentage = 5;
    uint8 public buyBackPercentage = 5;

    //========== MAPPINGS ==========//
    // total amount of XEON staked by users
    mapping(address => uint256) public stakedAmounts;
    // percentage of the pool owned by each staker
    mapping(address => uint256) public stakerPercentage;
    // votes for each staker
    mapping(address => uint256) public votes;
    // sum of all weighted votes
    uint256 public totalVotes;

    //========== EVENTS ==========//
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsDistributed(uint256 teamReward, uint256 buyBackAmount, uint256 stakersReward);
    event TokenSwapped(address indexed token, uint256 amount, uint256 wethReceived);
    event PoolLocked(uint256 epoch, uint256 timestamp);
    event PoolUnlocked(uint256 epoch, uint256 timestamp);
    event TeamPercentageUpdated(uint256 newPercentage);
    event PoolLockToggled(bool isLocked, uint256 timestamp);

    /**
     * @notice constructor to initialize the staking pool
     * @param _XEON address of XEON token
     * @param _WETH address of WETH token
     * @param _uniswapV2Router address of the Uniswap V2 Router
     * @param _uniswapV3Router address of the Uniswap V3 Router
     * @param _teamAddress address of the team ecosystem multisig
     */
    constructor(
        IERC20 _XEON, // base sepolia: 0x296dBB55cbA3c9beA7A8ac171542bEEf2ceD1163
        IERC20 _WETH, // base sepolia: 0x395cB7753B02A15ed1C099DFc36bF00171F18218
        IUniswapV2Router02 _uniswapV2Router, // base sepolia: 0x1689E7B1F10000AE47eBfE339a4f69dECd19F602
        ISwapRouter _uniswapV3Router, // base sepolia: 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4
        address _teamAddress // base sepolia: 0x56557c3266d11541c2D939BF6C05BFD29e881e55
    ) ERC20("Staked XEON", "stXEON") Ownable(msg.sender) {
        XEON = _XEON;
        WETH = _WETH;
        uniswapV2Router = _uniswapV2Router;
        uniswapV3Router = _uniswapV3Router;
        teamAddress = _teamAddress;

        isPoolLocked = false; // Start in an unlocked state
        nextEpochStart = uint64(block.timestamp) + UNLOCK_PERIOD; // epoch 1 starts after unlock period
    }

    //========== MODIFIERS ==========//

    // ensure caller is staker
    modifier isStaker() {
        require(balanceOf(msg.sender) > 0, "Address is not a staker");
        _;
    }

    // ensure pool is unlocked
    modifier whenUnlocked() {
        require(!isPoolLocked, "Staking/Unstaking is locked during the staking period.");
        _;
    }

    // ensure pool is locked
    modifier whenLocked() {
        require(isPoolLocked, "Cannot perform this action while the pool is unlocked.");
        _;
    }

    //========== stXEON OVERRIDES ==========//
    /**
     * @dev Prevents stXEON tokens from being transferred.
     * Overrides `transfer` and `transferFrom` to block transfers.
     */
    function transfer(address, uint256) public pure override returns (bool) {
        revert("stXEON is non-transferable");
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert("stXEON is non-transferable");
    }

    //========== STAKING FUNCTIONS ==========//

    /**
     * @notice Stake XEON tokens into the pool
     * @param amount The amount of XEON tokens to stake
     */
    function stake(uint256 amount) external whenUnlocked {
        require(amount > 0, "Cannot stake 0 tokens");

        XEON.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);

        if (stakedAmounts[msg.sender] == 0) {
            stakers.push(msg.sender);
        }

        stakedAmounts[msg.sender] += amount;

        // update staker's percentage of the pool
        _updateStakerPercentage(msg.sender);

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake XEON tokens from the pool
     * @dev Tokens can only be unstaked when the pool is unlocked.
     * @param amount The amount of XEON tokens to unstake
     */
    function unstake(uint256 amount) external whenUnlocked isStaker {
        require(amount > 0, "Cannot unstake 0 tokens");
        require(balanceOf(msg.sender) >= amount, "Insufficient staked balance");

        _burn(msg.sender, amount);
        stakedAmounts[msg.sender] -= amount;

        if (stakedAmounts[msg.sender] == 0) {
            _removeStaker(msg.sender);
        }

        // update staker's percentage of the pool
        _updateStakerPercentage(msg.sender);

        XEON.safeTransfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    //========== EPOCH MANAGEMENT ==========//

    /**
     * @notice Check and update the epoch and pool lock state
     * @dev Locks the pool at the start of a new epoch and unlocks it at the end.
     */
    function checkEpoch() external {
        if (block.timestamp >= nextEpochStart) {
            if (isPoolLocked) {
                _unlockPool();
            } else {
                _lockPool();
            }
        }
    }

    /**
     * @dev Internal function to lock the pool and start a new epoch.
     * when locking the pool, the buyback percentage is recalculated.
     */
    function _lockPool() internal whenUnlocked {
        isPoolLocked = true;

        // calculate the new buyback percentage
        _calculateNewBuybackPercentage();

        // next epoch starts after this epoch and next unlock period
        nextEpochStart = uint64(block.timestamp) + EPOCH_DURATION + UNLOCK_PERIOD;
        epoch++;

        emit PoolLocked(epoch, block.timestamp);
    }

    /**
     * @dev Internal function to unlock the pool
     */
    function _unlockPool() internal whenLocked {
        isPoolLocked = false;

        // next epoch starts after this current unlock period
        nextEpochStart = uint64(block.timestamp) + UNLOCK_PERIOD;

        // distribute rewards and buyback XEON
        _autoWithdrawRewards();
        _swapWETHForXEON();

        emit PoolUnlocked(epoch, block.timestamp);
    }

    //========== REWARD DISTRIBUTION==========//

    /**
     * @dev Internal function to distribute WETH rewards to the team, buyback, and stakers
     */
    function _autoWithdrawRewards() internal nonReentrant {
        uint256 totalWETH = WETH.balanceOf(address(this));
        uint256 teamReward = (totalWETH * teamPercentage) / 100;
        uint256 buyBackAmount = (totalWETH * buyBackPercentage) / 100;
        uint256 stakersReward = totalWETH - teamReward - buyBackAmount;

        // Distribute WETH
        WETH.transfer(teamAddress, teamReward);
        WETH.transfer(teamAddress, buyBackAmount);

        // Distribute to stakers
        uint256 totalStakedSupply = totalSupply(); // Renamed variable to avoid shadowing
        uint256 stakersLength = stakers.length;
        for (uint256 i = 0; i < stakersLength; i++) {
            address staker = stakers[i];
            uint256 reward = (stakedAmounts[staker] * stakersReward) / totalStakedSupply;
            WETH.transfer(staker, reward);
        }

        emit RewardsDistributed(teamReward, buyBackAmount, stakersReward);
    }

    /**
     * @notice Allows the owner to trigger rewards distribution at any time
     */
    function withdrawRewards() external onlyOwner {
        _autoWithdrawRewards();
    }

    /**
     * @notice Allows the owner to swap ERC20 tokens to WETH using Uniswap
     * @param token The address of the ERC20 token to swap
     * @param amount The amount of the token to swap
     */
    /* todo: add ETH handling for mainnet */
    function swapTokenToWETH(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Approve the Uniswap router to spend the tokens
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
    /**
     * @notice cast a vote for what percentage of pool rewards should be used
     * to buyback XEON from the LP.
     * @dev Only stakers can call this function, and votes are weighted by
     * total amount of XEON staked.
     *
     * @param percentage of XEON buyback being voted for (1-100)
     */
    function voteForBuybackPercentage(uint256 percentage) external isStaker {
        require(!isPoolLocked, "Voting is only allowed while the pool is unlocked");
        require(percentage >= 1 && percentage <= 100, "Invalid percentage");

        uint256 stakedBalance = balanceOf(msg.sender);
        uint256 totalStaked = totalSupply();
        uint256 weightedVote = (percentage * stakedBalance) / totalStaked;

        // remove the user's previous vote from the total votes, if any
        if (votes[msg.sender] > 0) {
            totalVotes -= votes[msg.sender];
        }

        // Add the new vote to the total votes
        votes[msg.sender] = weightedVote;
        totalVotes += weightedVote;
    }

    //========== INTERNAL FUNCTIONS ==========//

    /**
     * @dev Internal function to update the staker's percentage of the pool
     * @param staker The address of the staker to update
     */
    function _updateStakerPercentage(address staker) internal {
        uint256 totalStaked = totalSupply();
        if (totalStaked > 0) {
            stakerPercentage[staker] = (stakedAmounts[staker] * 100) / totalStaked;
        } else {
            stakerPercentage[staker] = 0;
        }
    }

    /**
     * @dev internal function to calculate the new buyback percentage
     * each staker's vote is proportional to the amount of XEON staked, relative
     * to the total amount staked. The previous buyback percentage is weighted
     * in to dampen percentage change between epochs.
     */
    function _calculateNewBuybackPercentage() internal {
        uint256 totalStaked = totalSupply();
        uint256 totalWeightedVotes;

        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            uint256 stakedBalance = balanceOf(staker);

            uint256 weightedVote;
            if (votes[staker] > 0) {
                weightedVote = votes[staker];
            } else {
                // Default vote value is the current buyBackPercentage + 10
                uint256 defaultVoteValue = buyBackPercentage + 10;
                // Ensure the default vote does not exceed 100%
                if (defaultVoteValue > 100) {
                    defaultVoteValue = 100;
                }
                weightedVote = (defaultVoteValue * stakedBalance) / totalStaked;
            }
            totalWeightedVotes += weightedVote;
        }

        // Calculate the new buyback percentage
        uint256 weightedAverage = totalWeightedVotes / totalStaked;
        buyBackPercentage = uint8((weightedAverage + uint256(buyBackPercentage)) / 2);

        // Reset votes for the next epoch
        totalVotes = 0;
        for (uint256 i = 0; i < stakers.length; i++) {
            votes[stakers[i]] = 0;
        }
    }

    /**
     * @dev internal function to remove a staker if they are no longer staked
     * @param staker address of the staker
     */
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

    /**
     * @dev Internal function to swap WETH for XEON and send to team address
     */
    /* todo: add ETH handling for mainnet */
    function _swapWETHForXEON() internal {
        uint256 totalWETH = WETH.balanceOf(address(this));
        uint256 amountToSwap = (totalWETH * buyBackPercentage) / 100;

        // Approve the Uniswap router to spend WETH
        WETH.approve(address(uniswapV2Router), amountToSwap);

        // Define the path for swapping WETH to XEON
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(XEON);

        // Swap WETH for XEON
        uint256[] memory amounts = uniswapV2Router.swapExactTokensForTokens(
            amountToSwap,
            0, // accept any amount of XEON
            path,
            address(this), // send XEON to this contract
            block.timestamp + 5 minutes // set a reasonable deadline
        );

        emit TokenSwapped(address(WETH), amountToSwap, amounts[1]);
    }

    //========== OWNER FUNCTIONS ==========//

    /**
     * @notice Allows the owner to update the team percentage for WETH rewards
     * @param newPercentage The new percentage for the team
     */
    function setTeamPercentage(uint256 newPercentage) external onlyOwner {
        require(newPercentage < 100, "Percentage must be less than 100");
        teamPercentage = uint8(newPercentage);
        emit TeamPercentageUpdated(newPercentage);
    }

    /* todo: for mainnet consolidate setter methods into `setParams(xeonAddress, wethAddress, uniswapV2Router, uniswapV3Router, teamPercentage)` */
    /**
     * @notice Updates the XEON token address.
     * @param _newXEON The new address of the XEON token.
     */
    function updateXEONAddress(IERC20 _newXEON) external onlyOwner {
        require(address(_newXEON) != address(0), "Invalid address");
        XEON = _newXEON;
    }

    /**
     * @notice Updates the WETH token address.
     * @param _newWETH The new address of the WETH token.
     */
    function updateWETHAddress(IERC20 _newWETH) external onlyOwner {
        require(address(_newWETH) != address(0), "Invalid address");
        WETH = _newWETH;
    }

    /**
     * @notice function for owner to toggle the pool lock state
     */
    function togglePoolLock() external onlyOwner {
        isPoolLocked = !isPoolLocked;

        if (isPoolLocked) {
            emit PoolLocked(epoch, block.timestamp);
        } else {
            emit PoolUnlocked(epoch, block.timestamp);
        }

        emit PoolLockToggled(isPoolLocked, block.timestamp);
    }
}
