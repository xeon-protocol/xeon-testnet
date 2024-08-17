// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUinswapV3Factory.sol";
import "./PriceOracle.sol";
import "./XeonFeeManagement.sol";
import "./XeonStorage.sol";
import "./XeonStructs.sol";

interface IPriceOracle {
    function getValueInWETH(address token) external view returns (uint256);
    function setTokenPriceInWETH(address token, uint256 priceInWETH) external;
    function setWETHPriceInUSD(uint256 priceInUSD) external;
}

pragma solidity 0.8.20;

interface IXeonStaking {
    function getAssignedAndUnassignedAmounts(address _addr)
        external
        view
        returns (uint256, uint256, uint256, uint256);
}

/**
 * @title Xeon Hedging
 * @author ByteZero <bytezero@xeon-protocol.io>
 * @author Jon Bray <jon@xeon-protocol.io>
 * @notice this is a testnet version of XeonHedging and should not be used in production
 */
contract XeonHedging_Test_V2 is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bool private isExecuting;
    bool private isAdmin;

    // core addresses
    address public priceOracle;
    IXeonStaking public stakingContract;
    IUniswapV2Factory public uniswapV2Factory;
    IUniswapV3Factory public uniswapV3Factory;

    address public xeonAddress;
    address public stakingAddress;
    address public wethAddress;
    address public usdtAddress;
    address public usdcAddress;

    //=============== MAPPINGS ===============//

    //=============== EVENTS ===============//
    event Received(address, uint256);
    event ContractInitialized(address indexed, address indexed);
    event OnDeposit(address indexed token, uint256 indexed amount, address indexed wallet);
    event OnWithdraw(address indexed token, uint256 indexed amount, address indexed wallet);
    event HedgeCreated(
        address indexed token, uint256 indexed dealId, uint256 createValue, HedgeType hedgeType, address indexed writer
    );
    event HedgePurchased(
        address indexed token, uint256 indexed dealId, uint256 startValue, HedgeType hedgeType, address indexed buyer
    );
    event HedgeSettled(
        address indexed token, uint256 indexed dealId, uint256 endValue, uint256 payOff, address indexed miner
    );
    event MinedHedge(
        uint256 dealId,
        address indexed miner,
        address indexed token,
        address indexed paired,
        uint256 tokenFee,
        uint256 pairFee
    );
    event TopupRequested(address indexed party, uint256 indexed hedgeId, uint256 topupAmount);
    event TopupAccepted(
        address indexed acceptor, uint256 indexed dealID, uint256 indexed requestID, uint256 pairedAmount
    );
    event ZapRequested(uint256 indexed hedgeId, address indexed party);
    event HedgeDeleted(uint256 indexed dealID, address indexed deletedBy);
    event FeesTransferred(address indexed token, address indexed to, uint256 amount);

    event EtherWithdrawn(address indexed to, uint256 amount);

    /**
     * @dev Helper function to check if the caller is a miner.
     *
     * This function verifies if the provided address belongs to a miner by checking if
     * the address has a positive deposited balance in the staking contract.
     *
     * Requirements:
     * - The `_addr` must be a valid Ethereum address.
     * - The `userBalanceMap` for the `stakingContract` must have a deposited balance greater than zero for the `_addr`.
     *
     * @param _addr The address to check.
     * @return bool Returns `true` if the address is a miner, otherwise `false`.
     */
    function isMiner(address _addr) internal view returns (bool) {
        (uint256 assignedForMining,,,) = stakingContract.getAssignedAndUnassignedAmounts(_addr);
        return assignedForMining > 0;
    }

    //=============== SETTERS ===============//

    //=============== GETTERS ===============//
    // hack: workaround for getting token decimals through IERC20 interface
    // since testnet tokens all have 18 decimals
    function getTokenDecimals() internal pure returns (uint256) {
        return 18;
    }

    // hack: simplified for testnet deployment
    function getUnderlyingValue(address _tokenAddress, uint256 _tokenAmount) public view returns (uint256, address) {
        uint256 valueInWETH = IPriceOracle(priceOracle).getValueInWETH(_tokenAddress);
        uint256 value = valueInWETH * _tokenAmount;
        return (value, wethAddress);
    }

    // hack: removed USDT, USDC for testnet deployment
    function getUserTokenBalances(address token, address user)
        public
        view
        returns (
            uint256 deposited,
            uint256 withdrawn,
            uint256 lockedInUse,
            uint256 withdrawable,
            uint256 withdrawableValue,
            address paired
        )
    {
        UserBalance memory uto = userBalanceMap[token][user];
        deposited = uto.deposited;
        withdrawn = uto.withdrawn;
        lockedInUse = uto.lockedInUse;
        withdrawable = uto.deposited - uto.withdrawn - uto.lockedInUse;

        // Calculate the withdrawable value in WETH
        (withdrawableValue, paired) = getUnderlyingValue(token, withdrawable);

        return (deposited, withdrawn, lockedInUse, withdrawable, withdrawableValue, paired);
    }

    // internal - retrieve a subset of an array based on startIndex and limit
    function getSubset(uint256[] storage fullArray, uint256 startIndex, uint256 limit)
        internal
        view
        returns (uint256[] memory)
    {
        uint256 length = fullArray.length;
        require(startIndex <= length, "Start index equal array length");
        if (length == 0) {
            return new uint256[](0); //return empty array
        }
        uint256 actualLimit = (length - startIndex < limit) ? length - startIndex : limit;
        uint256[] memory subset = new uint256[](actualLimit);
        for (uint256 i = 0; i < actualLimit; i++) {
            subset[i] = fullArray[startIndex + i];
        }
        // Resize the array to remove unused slots
        assembly {
            mstore(subset, actualLimit)
        }
        return subset;
    }

    // retrieve a subset of tokens from a user's history.
    function getUserHistory(address user, uint256 startIndex, uint256 limit) public view returns (address[] memory) {
        address[] storage tokens = userERC20s[user];
        uint256 length = tokens.length;
        require(startIndex <= length, "Invalid start index");
        if (length == 0) {
            return new address[](0); //return empty array
        }
        uint256 actualLimit = length - startIndex < limit ? length - startIndex : limit;
        address[] memory result = new address[](actualLimit);
        for (uint256 i = startIndex; i < startIndex + actualLimit; i++) {
            result[i - startIndex] = tokens[i];
        }
        // Resize the array to remove unused slots
        assembly {
            mstore(result, actualLimit)
        }
        return result;
    }

    // retrieve a subset of options or swaps created/taken by a user
    function getUserOptionsCreated(address user, uint256 startIndex, uint256 limit)
        public
        view
        returns (uint256[] memory)
    {
        return getSubset(myoptionsCreated[user], startIndex, limit);
    }

    function getUserSwapsCreated(address user, uint256 startIndex, uint256 limit)
        public
        view
        returns (uint256[] memory)
    {
        return getSubset(myswapsCreated[user], startIndex, limit);
    }

    function getUserOptionsTaken(address user, uint256 startIndex, uint256 limit)
        public
        view
        returns (uint256[] memory)
    {
        return getSubset(myoptionsTaken[user], startIndex, limit);
    }

    function getUserSwapsTaken(address user, uint256 startIndex, uint256 limit)
        public
        view
        returns (uint256[] memory)
    {
        return getSubset(myswapsTaken[user], startIndex, limit);
    }

    // retrieve PnL for user
    function getEquivUserPL(address user, address pairedCurrency)
        external
        view
        returns (uint256 profits, uint256 losses)
    {
        return (userPLMap[pairedCurrency][user].profits, userPLMap[pairedCurrency][user].losses);
    }

    // retrieve a subset of options or swaps created/taken
    function getAllOptions(uint256 startIndex, uint256 limit) public view returns (uint256[] memory) {
        return getSubset(optionsCreated, startIndex, limit);
    }

    function getAllSwaps(uint256 startIndex, uint256 limit) public view returns (uint256[] memory) {
        return getSubset(equityswapsCreated, startIndex, limit);
    }

    // retrieve a subset of options or swaps taken
    function getAllOptionsTaken(uint256 startIndex, uint256 limit) public view returns (uint256[] memory) {
        return getSubset(optionsTaken, startIndex, limit);
    }

    function getAllSwapsTaken(uint256 startIndex, uint256 limit) public view returns (uint256[] memory) {
        return getSubset(equityswapsTaken, startIndex, limit);
    }

    // retrieve purchased options or swaps for ERC20 address
    function getBoughtOptionsERC20(address _token, uint256 startIndex, uint256 limit)
        public
        view
        returns (uint256[] memory)
    {
        return getSubset(optionsBought[_token], startIndex, limit);
    }

    function getBoughtSwapsERC20(address _token, uint256 startIndex, uint256 limit)
        public
        view
        returns (uint256[] memory)
    {
        return getSubset(equityswapsBought[_token], startIndex, limit);
    }

    // retrieve settled options or swaps for ERC20 address
    function getSettledOptionsERC20(address _token, uint256 startIndex, uint256 limit)
        public
        view
        returns (uint256[] memory)
    {
        return getSubset(optionsSettled[_token], startIndex, limit);
    }

    function getSettledSwapsERC20(address _token, uint256 startIndex, uint256 limit)
        public
        view
        returns (uint256[] memory)
    {
        return getSubset(equityswapsSettled[_token], startIndex, limit);
    }

    // retrieve a subset of options or swaps for a specific token
    function getOptionsForToken(address _token, uint256 startIndex, uint256 limit)
        public
        view
        returns (uint256[] memory)
    {
        return getSubset(tokenOptions[_token], startIndex, limit);
    }

    function getSwapsForToken(address _token, uint256 startIndex, uint256 limit)
        public
        view
        returns (uint256[] memory)
    {
        return getSubset(tokenSwaps[_token], startIndex, limit);
    }

    function getHedgeDetails(uint256 _dealID) public view returns (HedgingOption memory) {
        HedgingOption storage hedge = hedgeMap[_dealID];
        require(hedge.owner != address(0), "Option does not exist");
        return hedge;
    }

    function getHedgeRange(uint256 startId, uint256 endId) public view returns (HedgingOption[] memory) {
        require(endId >= startId, "Invalid range");

        uint256 rangeSize = endId - startId + 1;
        HedgingOption[] memory result = new HedgingOption[](rangeSize);
        uint256 count = 0;

        for (uint256 i = 0; i < rangeSize; i++) {
            uint256 dealId = startId + i;
            HedgingOption storage hedge = hedgeMap[dealId];
            if (hedge.owner != address(0)) {
                result[count] = hedge;
                count++;
            }
        }

        // Resize the array to remove unused slots
        assembly {
            mstore(result, count)
        }

        return result;
    }

    // Function to get the length of the options array for a specific token
    function getCountTokenOptions(address token) external view returns (uint256) {
        return tokenOptions[token].length;
    }

    function getCountTokenSwaps(address token) external view returns (uint256) {
        return tokenSwaps[token].length;
    }

    // Function to get the length of the options array for a specific user
    function getUserOptionCount(address user, bool store) external view returns (uint256) {
        if (store) {
            return myoptionsCreated[user].length;
        } else {
            return myoptionsTaken[user].length;
        }
    }

    function getUserSwapCount(address user, bool store) external view returns (uint256) {
        if (store) {
            return myswapsCreated[user].length;
        } else {
            return myswapsTaken[user].length;
        }
    }

    //=============== CONSTRUCTOR ===============//
    constructor(address _priceOracle, address _stakingContract) Ownable(msg.sender) ReentrancyGuard() {
        require(_priceOracle != address(0), "Invalid Oracle Address");

        priceOracle = _priceOracle;
        stakingContract = IXeonStaking(_stakingContract);

        wethAddress = 0x395cB7753B02A15ed1C099DFc36bF00171F18218;
        xeonAddress = 0x0000000000000000000000000000000000000000;

        feeNumerator = 5;
        feeDenominator = 1000;

        emit ContractInitialized(_priceOracle, _stakingContract); // Use _stakingContract here
    }

    //=============== EXTERNAL METHODS ===============//
    /**
     * @dev Allows users to deposit ERC-20 tokens into the protocol.
     * This function uses SafeERC20 to safely transfer tokens from the user to the contract.
     * It also updates the protocol's records of equivalent token deposits for major pairs (WETH, USDT, USDC).
     * Checks before & after token balance, to prevent discrepancies for fee-on-transfer tokens, between the reported and actual balances.
     * Requirements:
     * - The amount of tokens to be deposited must be greater than zero.
     * - The token address must be valid (non-zero).
     *
     * Emits an {OnDeposit} event.
     *
     * @param _token The address of the ERC-20 token to be deposited.
     * @param _amount The amount of tokens to be deposited.
     */
    // hack: removed USDT, USDC reference for testnet
    function depositToken(address _token, uint256 _amount) external nonReentrant {
        require(_amount > 0 && _token != address(0), "You're attempting to transfer 0 tokens");

        IERC20 token = IERC20(_token);

        // Get contract balance of the token before transfer
        uint256 initialContractBalance = token.balanceOf(address(this));

        // Transfer tokens from sender to contract
        SafeERC20.safeTransferFrom(token, msg.sender, address(this), _amount);

        // Get contract balance of the token after transfer
        uint256 finalContractBalance = token.balanceOf(address(this));

        // Calculate the actual amount received after transfer
        uint256 receivedAmount = finalContractBalance - initialContractBalance;

        // Update WETH equivalent deposits
        (uint256 marketValue,) = getUnderlyingValue(_token, receivedAmount);
        wethEquivDeposits += marketValue;

        // Log user balance & tokens
        UserBalance storage uto = userBalanceMap[_token][msg.sender];
        if (uto.deposited == 0) {
            userERC20s[msg.sender].push(_token);
        }
        uto.deposited += receivedAmount;

        // Log new token address
        if (protocolBalanceMap[_token].deposited == 0) {
            userERC20s[address(this)].push(_token);
            depositedTokensLength++;
        }
        protocolBalanceMap[_token].deposited += receivedAmount;

        // Emit deposit event
        emit OnDeposit(_token, receivedAmount, msg.sender);
    }

    /**
     * @dev Allows users to withdraw ERC-20 tokens from the protocol.
     * This function ensures the user has sufficient withdrawable balance and applies a fee for major pairs (WETH, USDT, USDC).
     *
     * Requirements:
     * - The amount to be withdrawn must be greater than zero and less than or equal to the user's available balance.
     * - The caller must not be the contract itself.
     *
     * Emits an {OnWithdraw} event.
     *
     * @param token The address of the ERC-20 token to be withdrawn.
     * @param amount The amount of tokens to be withdrawn.
     */
    // hack: removed USDT, USDC reference for testnet
    function withdrawToken(address token, uint256 amount) external nonReentrant {
        // Read user balances into local variables
        (,,, uint256 withdrawable,,) = getUserTokenBalances(token, msg.sender);

        require(amount <= withdrawable && amount > 0, "You have Insufficient available balance");
        require(msg.sender != address(this), "Not allowed");

        // Apply withdrawal fee only for WETH
        uint256 tokenFee;
        if (token == wethAddress) {
            tokenFee = calculateFee(amount) / 10;
            protocolCashierFees[token] += tokenFee;
            userBalanceMap[token][address(this)].deposited += tokenFee;
        }

        // Withdraw
        userBalanceMap[token][msg.sender].withdrawn += amount;

        // Transfer the tokens
        require(IERC20(token).transfer(msg.sender, amount - tokenFee), "Transfer failed");

        // Log withdrawal
        protocolBalanceMap[token].withdrawn += amount;

        // Log WETH equivalent withdrawals
        (uint256 marketValue,) = getUnderlyingValue(token, amount);
        wethEquivWithdrawals += marketValue;

        // Emit withdrawal event
        emit OnWithdraw(token, amount, msg.sender);
    }

    /**
     * @dev Transfers collected fees from the protocol to a specified wallet address.
     * This function debits the protocol's user balance map and credits the recipient's user balance map.
     *
     * Requirements:
     * - The protocol must have a sufficient balance to transfer the specified amount.
     * - The amount to be transferred must be specified and non-zero.
     *
     * Emits a {FeesTransferred} event.
     *
     * @param token The address of the token for which the fees are being transferred.
     * @param to The address of the recipient wallet to which the fees are to be credited.
     * @param amount The amount of fees to be transferred.
     */
    function transferCollectedFees(address token, address to, uint256 amount) external onlyOwner {
        require(userBalanceMap[token][address(this)].deposited >= amount, "Insufficient protocol balance");

        userBalanceMap[token][address(this)].deposited -= amount;
        userBalanceMap[token][to].deposited += amount;

        emit FeesTransferred(token, to, amount);
    }

    /**
     * @dev Creates a hedge, which can be a call option, put option, or equity swap.
     * The premium or buying cost is paid in the paired token of the underlying asset in the deal.
     * There is no premium for swaps, and swap collateral must be equal for both parties as the settle function relies on this implementation.
     * Users can only write options with an underlying value and strike value that currently puts the taker in a loss.
     *
     * Requirements:
     * - The tool type must be valid (0 for CALL, 1 for PUT, 2 for SWAP).
     * - The amount and cost must be greater than zero.
     * - The deadline must be a future timestamp.
     * - The user must have sufficient withdrawable balance in the vault.
     * - For CALL options, the strike price must be greater than the market value.
     * - For PUT options, the strike price must be less than the market value.
     * - For SWAPs, the collateral value must be equal.
     *
     * Emits a {HedgeCreated} event.
     *
     * @param tool The type of hedge (0 for CALL, 1 for PUT, 2 for SWAP).
     * @param token The address of the ERC-20 token.
     * @param amount The amount of the underlying asset.
     * @param cost The premium or buying cost.
     * @param strikeprice The strike price of the option.
     * @param deadline The expiration timestamp of the hedge.
     */
    function createHedge(
        uint256 tool,
        address token,
        uint256 amount,
        uint256 cost,
        uint256 strikeprice,
        uint256 deadline
    ) external nonReentrant {
        require(tool <= 2 && amount > 0 && cost > 0 && deadline > block.timestamp, "Invalid option parameters");
        (,,, uint256 withdrawable,,) = getUserTokenBalances(token, msg.sender);
        require(withdrawable > 0 && withdrawable >= amount, "Insufficient Vault Balance. Deposit more tokens");

        // Assign option values directly to the struct
        HedgingOption storage newOption = hedgeMap[dealID];
        newOption.owner = msg.sender;
        newOption.token = token;
        newOption.status = 1;
        newOption.amount = amount;
        (newOption.createValue, newOption.paired) = getUnderlyingValue(token, amount);
        newOption.cost = cost;
        newOption.strikeValue = strikeprice * amount;
        newOption.dt_expiry = deadline;
        newOption.dt_created = block.timestamp;

        if (tool == 0) {
            newOption.hedgeType = HedgeType.CALL;
        } else if (tool == 1) {
            newOption.hedgeType = HedgeType.PUT;
        } else if (tool == 2) {
            newOption.hedgeType = HedgeType.SWAP;
        } else {
            revert("Invalid tool option");
        }

        // Users can only write options with an underlying value and strike value that puts the taker in a loss now
        if (newOption.hedgeType == HedgeType.CALL) {
            require(newOption.strikeValue > newOption.createValue, "Strike price must be greater than market value");
        } else if (newOption.hedgeType == HedgeType.PUT) {
            require(newOption.strikeValue < newOption.createValue, "Strike price must be less than market value");
        }

        // Update user balances for token in hedge
        userBalanceMap[token][msg.sender].lockedInUse += amount;

        // Update arrays
        if (newOption.hedgeType == HedgeType.SWAP) {
            require(cost >= newOption.createValue, "Swap collateral must be equal value");
            myswapsCreated[msg.sender].push(dealID);
            equityswapsCreated.push(dealID);
            equityswapsCreatedLength++;
            tokenSwaps[token].push(dealID);
        } else {
            myoptionsCreated[msg.sender].push(dealID);
            optionsCreated.push(dealID);
            optionsCreatedLength++;
            tokenOptions[token].push(dealID);
        }

        // Log protocol analytics
        dealID++;
        hedgesCreatedVolume[newOption.paired] += newOption.createValue;

        // Emit hedge creation event
        emit HedgeCreated(token, dealID, newOption.createValue, newOption.hedgeType, msg.sender);
    }

    /**
     * @dev Purchases a hedge, which can be a call option, put option, or equity swap.
     * Hedge costs are in the paired currency of the underlying token.
     * The cost is paid out to the writer immediately, with no protocol fees applied.
     * For equity swaps, the cost is equal to the underlying value as 100% collateral is required.
     * Strike value is not set here; maturity calculations are left to the settlement function.
     * Debits costs and credits them to withdrawn for the taker. Profits are recorded as deposits on settlement.
     *
     * Requirements:
     * - The hedge must be available (status = 1).
     * - The hedge must not be expired.
     * - The caller must not be the hedge owner.
     * - The caller must have sufficient free vault balance.
     * - The deal ID must be valid and less than the current deal ID.
     *
     * Emits a {HedgePurchased} event.
     *
     * @param _dealID The ID of the hedge to be purchased.
     */
    function buyHedge(uint256 _dealID) external nonReentrant {
        HedgingOption storage hedge = hedgeMap[_dealID];
        UserBalance storage stk = userBalanceMap[hedge.paired][msg.sender];

        // Validate the hedge status and ownership
        require(hedge.status == 1, "Hedge already taken");
        require(block.timestamp < hedge.dt_expiry, "Hedge expired");
        require(_dealID < dealID && msg.sender != hedge.owner, "Invalid option ID | Owner can't buy");

        // Fetch the user's withdrawable balance for the paired token
        (,,, uint256 withdrawable,,) = getUserTokenBalances(hedge.paired, msg.sender);
        require(withdrawable >= hedge.cost, "Insufficient free Vault balance");

        // Calculate, check, and update start value based on the hedge type
        (hedge.startValue,) = (hedge.hedgeType == HedgeType.SWAP)
            ? getUnderlyingValue(hedge.token, hedge.amount + hedge.cost) // Include cost in calculation for SWAP
            : getUnderlyingValue(hedge.token, hedge.amount); // Exclude cost for CALL and PUT

        require(hedge.startValue > 0, "Math error whilst getting price"); // Sanity check

        // Transfer cost from Taker userBalanceMap to Writer userBalanceMap
        if (hedge.hedgeType != HedgeType.SWAP) {
            userBalanceMap[hedge.paired][msg.sender].withdrawn += hedge.cost;
            userBalanceMap[hedge.token][hedge.owner].deposited += hedge.cost;
        }

        // Update hedge struct to indicate it is taken and record the taker
        hedge.dt_started = block.timestamp;
        hedge.taker = msg.sender;
        hedge.status = 2; // Update status to taken

        // Store updated structs back to storage
        userBalanceMap[hedge.paired][msg.sender] = stk;
        hedgeMap[_dealID] = hedge;

        // Update arrays and taken count
        if (hedge.hedgeType == HedgeType.SWAP) {
            equityswapsTakenLength++;
            equityswapsBought[hedge.token].push(_dealID);
            equityswapsTaken.push(_dealID);
            myswapsTaken[msg.sender].push(_dealID);
        } else {
            optionsTakenLength++;
            optionsBought[hedge.token].push(_dealID);
            optionsTaken.push(_dealID);
            myoptionsTaken[msg.sender].push(_dealID);
        }

        // Log pair tokens involved in protocol revenue
        if (hedgesTakenVolume[hedge.paired] == 0) {
            pairedERC20s[address(this)].push(hedge.paired);
        }

        // Protocol Revenue Trackers
        hedgesTakenVolume[hedge.paired] += hedge.startValue;
        hedgesCostVolume[hedge.paired] += hedge.cost;

        if (hedge.hedgeType == HedgeType.SWAP) {
            swapsVolume[hedge.paired] += hedge.startValue;
        } else if (hedge.hedgeType == HedgeType.CALL) {
            optionsVolume[hedge.paired] += hedge.startValue;
        }

        // Emit the HedgePurchased event
        emit HedgePurchased(hedge.token, _dealID, hedge.startValue, hedge.hedgeType, msg.sender);
    }

    /**
     * @dev Deletes an untaken or expired and unexercised hedge.
     * Only the owner or a miner can delete the hedge under specific conditions.
     *
     * Conditions and rules:
     * - **Owner Deletion**: The owner can delete an untaken hedge before it is taken (status = 1).
     * - **Owner Deletion Post Expiry**: The owner can also delete the hedge after it expires and if it remains unexercised (status != 3).
     * - **Miner Deletion**: A miner can delete an expired and unexercised hedge (status = 2) and receives a fee for doing so.
     * - **Taker Deletion**: Prohibited.
     * - **Equity Swaps**: Cannot be deleted once taken, only settled.
     * - **Fee Handling**: If a miner deletes the hedge, the fee is split between the miner and the protocol.
     * - **Balance Restoration**: Upon deletion, the remaining balance after fees is restored to the hedge owner.
     *
     * Requirements:
     * - The hedge must be in a valid state for deletion (status = 1 or status = 2).
     * - The caller must be the owner if the hedge is untaken (status = 1).
     * - The caller must be the owner or a miner if the hedge is expired and unexercised (status = 2).
     * - The hedge must be expired if a miner is deleting it.
     * - Equity swaps (HedgeType.SWAP) cannot be deleted if taken.
     *
     * @param _dealID The ID of the hedge to be deleted.
     */
    function deleteHedge(uint256 _dealID) public nonReentrant {
        HedgingOption storage hedge = hedgeMap[_dealID];
        require(hedge.status == 1 || hedge.status == 2, "Invalid hedge status");

        // Check the caller's authority based on the hedge status
        if (hedge.status == 2) {
            require(msg.sender == hedge.owner || isMiner(msg.sender), "Owner or miner only can delete");
            require(block.timestamp >= hedge.dt_expiry, "Hedge must be expired before deleting");
        } else if (hedge.status == 1) {
            require(msg.sender == hedge.owner, "Only owner can delete");
        }

        // Ensure equity swaps cannot be deleted once taken
        require(hedge.hedgeType != HedgeType.SWAP && hedge.status == 1, "Swap can't be deleted");

        // Miner deleting an expired hedge
        if (msg.sender != hedge.owner) {
            require(block.timestamp > hedge.dt_expiry, "Hedge must be expired");
            uint256 fee = calculateFee(hedge.amount);
            uint256 feeSplit = fee / 2;

            // Transfer fee to miner and protocol
            userBalanceMap[hedge.token][msg.sender].deposited += feeSplit;
            userBalanceMap[hedge.token][address(this)].deposited += feeSplit;

            // Restore the remaining balance to the hedge owner
            uint256 amountAfterFee = hedge.amount - fee;
            userBalanceMap[hedge.token][hedge.owner].lockedInUse -= hedge.amount;
            userBalanceMap[hedge.token][hedge.owner].withdrawn += amountAfterFee;

            // Log the mining data for the miner
            logMiningData(msg.sender);

            // Log analytics fees
            logAnalyticsFees(hedge.token, feeSplit, 0, hedge.amount);
        } else {
            // Owner deleting the hedge
            userBalanceMap[hedge.token][hedge.owner].lockedInUse -= hedge.amount;
            userBalanceMap[hedge.token][hedge.owner].withdrawn += hedge.amount;
        }

        // Delete the hedge
        delete hedgeMap[_dealID];

        // Emit event
        emit HedgeDeleted(_dealID, msg.sender);
    }

    /**
     * @notice Initiates a top-up request for a hedging option.
     *
     * This function allows any party involved in a hedging option to initiate a top-up request.
     * The owner or the taker can match the top-up amount.
     * After the request, the start value of the hedging option is updated accordingly.
     * User balances are not updated here, this is initiation only.
     *
     * Conditions and rules:
     * - Any party involved in the hedging option can initiate a top-up request.
     * - Only the accepter of the hedging option can match the top-up amount.
     * - The request amount can be incremented if it has not been accepted yet.
     *
     * Requirements:
     * - The caller must be either the owner or the taker of the hedging option.
     *
     * @param _dealID The unique identifier of the hedging option.
     * @param amount The amount to be topped up.
     */
    function topupRequest(uint256 _dealID, uint256 amount) external nonReentrant {
        HedgingOption storage hedge = hedgeMap[_dealID];

        // Get token decimal for calculations
        // hack: testnet tokens all have 18 decimals
        uint256 tokenDecimals = 18;
        // uint256 tokenDecimals = getTokenDecimals(hedge.token);

        // Check the caller's authority
        require(msg.sender == hedge.owner || msg.sender == hedge.taker, "Invalid party to top up");

        // Increment the top-up request ID for each new request
        topupRequestID += 1;
        hedge.topupRequests.push(topupRequestID);
        topupMap[topupRequestID].requester = msg.sender;

        // Determine the token associated with the hedging option
        uint256 pairedAmount;

        // Calculate the paired amount based on the sender (owner or taker)
        if (msg.sender == hedge.owner) {
            // Owner tops up with tokens, increment startValue directly
            (uint256 underlyingValue,) = getUnderlyingValue(hedge.token, 1);
            pairedAmount = amount * (10 ** tokenDecimals) / underlyingValue;
            topupMap[topupRequestID].amountWriter += amount;
        } else {
            // Taker tops up with paired currency, increment startValue directly
            pairedAmount = amount;
            topupMap[topupRequestID].amountTaker += amount;
        }

        // Update the start value of the hedging option by adding the paired amount
        hedge.startValue += pairedAmount;

        // Update the hedging option in the mapping
        hedgeMap[_dealID] = hedge;

        // Emit an event indicating that a top-up has been requested
        emit TopupRequested(msg.sender, _dealID, amount);
    }

    /**
     * @notice Accepts a top-up request for a hedging option.
     *
     * This function allows the owner or the taker of a hedging option to accept a top-up request
     * initiated by the other party. Once accepted, the top-up amount is added to the relevant
     * balances, and collateral is locked into the deal for both parties.
     *
     * Requirements:
     * - The caller must be either the owner or the taker of the hedging option.
     * - The top-up request must not have been previously accepted.
     * - The caller cannot be the requester of the top-up.
     *
     * @param _requestID The unique identifier of the top-up request.
     * @param _dealID The unique identifier of the hedging option.
     */
    function acceptRequest(uint256 _requestID, uint256 _dealID) external nonReentrant {
        TopupData storage request = topupMap[_requestID];
        HedgingOption storage hedge = hedgeMap[_dealID];

        // Get token decimal for calculations
        // IERC20 token = IERC20(hedge.token);
        // uint256 tokenDecimals = getTokenDecimals(hedge.token);
        // hack: testnet tokens all have 18 decimals
        uint256 tokenDecimals = 18;

        // Ensure the caller's authority and the state of the top-up request
        require(msg.sender == hedge.owner || msg.sender == hedge.taker, "Invalid party to accept");
        require(request.state == 0, "Request already accepted");
        require(msg.sender != request.requester, "Requester can't accept the topup");

        // Determine the token associated with the hedging option
        address tokenAddr = hedge.token;
        uint256 pairedAmount;
        uint256 underlyingValue;

        // Calculate the paired amount based on the sender (owner or taker)
        if (msg.sender == hedge.owner) {
            // Owner accepts top-up with tokens
            (underlyingValue,) = getUnderlyingValue(tokenAddr, 1);
            pairedAmount = request.amountTaker * (10 ** tokenDecimals) / underlyingValue;
            // Update the hedging option balances and start value for the owner
            hedge.amount += pairedAmount;
            request.amountWriter += pairedAmount;
        } else {
            // Taker accepts top-up with paired currency
            (underlyingValue,) = getUnderlyingValue(tokenAddr, 1);
            pairedAmount = request.amountWriter * underlyingValue / (10 ** tokenDecimals);
            // Update the hedging option balances and start value for the taker
            hedge.cost += pairedAmount;
            request.amountTaker += pairedAmount;
        }

        // Lock collateral into deal for both parties
        address ownerToken = hedge.token;
        address takerToken = hedge.paired;
        uint256 ownerAmountToUse = request.amountWriter;
        uint256 takerAmountToUse = request.amountTaker;

        // Ensure that the parties have sufficient balance to cover the top-up
        (,,, uint256 ownerWithdrawable,,) = getUserTokenBalances(ownerToken, hedge.owner);
        require(ownerWithdrawable >= ownerAmountToUse, "Insufficient owner collateral");
        userBalanceMap[ownerToken][hedge.owner].lockedInUse += ownerAmountToUse; // lock collateral in deal
        userBalanceMap[ownerToken][hedge.owner].deposited += takerAmountToUse; // receive cost from taker

        (,,, uint256 takerWithdrawable,,) = getUserTokenBalances(takerToken, hedge.taker);
        require(takerWithdrawable >= takerAmountToUse, "Insufficient taker collateral");
        userBalanceMap[takerToken][hedge.taker].withdrawn += takerAmountToUse; // send cost to taker

        // Update the state of the top-up request to indicate acceptance and record the acceptance time
        request.state = 1;
        request.acceptTime = block.timestamp;

        // Emit an event indicating that the top-up request has been accepted
        emit TopupAccepted(msg.sender, _dealID, _requestID, pairedAmount);
    }

    /**
     * @notice Rejects a top-up request for a hedging option.
     *
     * This function allows the owner or the taker of a hedging option to reject a top-up request.
     * Once rejected, the state of the top-up request is updated to indicate rejection.
     *
     * Requirements:
     * - The caller must be either the owner or the taker of the hedging option.
     * - The top-up request must not have been previously accepted or rejected.
     *
     * @param _dealID The unique identifier of the hedging option.
     * @param _requestID The unique identifier of the top-up request.
     */
    function rejectTopupRequest(uint256 _dealID, uint256 _requestID) external {
        HedgingOption storage hedge = hedgeMap[_dealID];
        require(msg.sender == hedge.owner || msg.sender == hedge.taker, "Invalid party to reject");
        require(topupMap[_requestID].state == 0, "Request already accepted or rejected");

        // Update the state of the top-up request to indicate rejection
        topupMap[_requestID].state = 2;
    }

    /**
     * @notice Cancels a top-up request initiated by the owner.
     *
     * This function allows the owner of a hedging option to cancel a top-up request initiated by them.
     * Once canceled, the state of the top-up request is updated to indicate cancellation.
     *
     * Requirements:
     * - The top-up request must not have been previously accepted.
     * - The caller must be the requester of the top-up request.
     *
     * @param _requestID The unique identifier of the top-up request.
     */
    function cancelTopupRequest(uint256 _requestID) external {
        require(topupMap[_requestID].amountTaker == 0, "Request already accepted");
        require(topupMap[_requestID].requester == msg.sender, "Only owner can cancel");

        // Update the state of the top-up request to indicate cancellation
        topupMap[_requestID].state = 2;
    }

    /**
     * @notice Initiates a request to activate a "zap" for a hedging option.
     *
     * This function allows the owner or the taker of an Equity Swap to request a Zap.
     * The "zap" feature enables experdited settlement before expiry date.
     *
     * Requirements:
     * - The caller must be either the owner or the taker of the hedging option.
     * - The hedging option must have already been taken.
     * - The hedge must be Equity Swap type to benefit from the "zap".
     * - Call & Put options are excerised at Taker's discretion before expiry, zap benefits Writer to end sooner
     * - If both parties agree to Zap, expiry date on the deal is updated to now:
     * ---Taker loses right to exercise Call or Put Option.
     * ---Equity Swaps are unaffected. Setllement can now be triggered sooner.
     *
     * @param _dealID The unique identifier of the hedging option.
     */
    function zapRequest(uint256 _dealID) external {
        HedgingOption storage hedge = hedgeMap[_dealID];

        // Check caller's authority, is either owner or taker
        require(msg.sender == hedge.owner || msg.sender == hedge.taker, "Invalid party to request");
        require(hedge.dt_started > hedge.dt_created, "Hedge not taken yet");

        // Update the corresponding "zap" flag based on the caller
        if (msg.sender == hedge.owner) {
            hedge.zapWriter = true;
        } else {
            hedge.zapTaker = true;
        }

        // Update expiry date to now if flags are true for both parties
        if (hedge.zapWriter && hedge.zapTaker) {
            hedge.dt_expiry = block.timestamp;
        }

        // Emit an event indicating that a "zap" has been requested
        emit ZapRequested(_dealID, msg.sender);
    }

    /**
     * @notice Initiates the settlement process for a hedging option.
     *
     * This function handles the settlement of a hedging option, whether it's a call option, put option, or swap.
     * The settlement involves determining the payoff based on the underlying value, updating user balances, and distributing fees.
     *
     * Settlement Process Overview:
     * - The value is always measured in paired currency, token value is calculated using the 'getUnderlyingValue' function.
     * - The strike value is set by the writer, establishing the strike price. The start value is set when the hedge is initiated.
     * - Premium is the cost and is paid in the pair currency of the underlying token.
     * - For swaps, the cost equals 100% of the underlying start value, acting as collateral rather than hedge premium.
     * - The payoff, which is the difference between the market value and strike value, is paid in underlying or pair currency.
     * - Losses are immediately debited from withdrawn funds. For winners, profits are credited directly to the deposited balance.
     * - Initials for both parties are restored by moving funds from locked in use to deposit, which is the reverse of creating or buying.
     * - Fees are collected in paired tokens if option and swap PayOffs were done in paired tokens.
     * - Fees are collected in underlying tokens if option and swap PayOffs were done in underlying tokens.
     * - Settlement fees are collected into 'address(this)' userBalanceMap and manually distributed as dividends to a staking contract.
     * - Miners can settle deals after they expire, important for Equity Swaps not Options. For options Miners can only delete unexercised options.
     * - Miners have no right to validate or settle Equity Swaps. But for Options and Loans (in our lending platform) they can after expiry.
     * - Miners can pick deals with tokens and amounts they wish to mine to avoid accumulating mining rewards in unwanted tokens.
     * - Each wallet has to log each token interacted with for the sake of pulling all balances credited to it on settlement. This allows for net worth valuations on wallets.
     * - Protocol revenues are stored under 'userBalanceMap[address(this)]' storage. On revenue, protocol revenue is withdrawn manually and sent to the staking wallet.
     * - Takers only can settle/exercise open call options and put options before expiry. After expiry, it's deleted and taxed.
     * - Both parties have the ability to settle equity swaps, but only after expiry.
     *
     * Conditions and Rules:
     * - Call and put options can only be settled by miners or the taker.
     * - Only the taker can settle before expiry; after expiry, the option is deleted.
     * - Swaps require fast settlement after expiry and can be settled by the miner or any of the parties in the deal.
     * - If a hedge has Zap request consesus on experdited settlement, the expiry date is updated to now.
     * - If the loser of a deal does not have enough collateral to pay the winner PayOff, all the losers collateral is used to pay the winner.
     * - For Put Options, Takers must take care to excerice the option whilst the collateral from the Owner still has value to cover the PayOff.
     * - After the PayOff is deducted from losers collateral, any remaining value or balance locked in the deal is restored to the loser.
     *
     * Requirements:
     * - The caller must be either the owner or the taker of the hedging option.
     *
     * @param _dealID The unique identifier of the hedging option.
     */
    function settleHedge(uint256 _dealID) external {
        HedgeInfo memory hedgeInfo;
        require(_dealID < dealID, "Invalid option ID");
        HedgingOption storage option = hedgeMap[_dealID];
        require(option.status == 2, "Hedge already settled");

        // Validate caller's authority based on hedge type and timing
        if (option.hedgeType == HedgeType.CALL || option.hedgeType == HedgeType.PUT) {
            require(msg.sender == option.taker || isMiner(msg.sender), "Invalid party to settle");
            if (block.timestamp < option.dt_expiry) {
                require(msg.sender == option.taker, "Only the taker can settle before expiry");
            } else {
                deleteHedge(_dealID); // Taker cannot settle after expiry, hedge is deleted
                return;
            }
        } else if (option.hedgeType == HedgeType.SWAP) {
            require(
                msg.sender == option.owner || msg.sender == option.taker || isMiner(msg.sender),
                "Invalid party to settle"
            );
            require(
                option.zapWriter && option.zapTaker || block.timestamp >= option.dt_expiry,
                "Hedge cannot be settled yet"
            );
        }

        (hedgeInfo.underlyingValue,) = getUnderlyingValue(option.token, option.amount);

        UserBalance storage oti = userBalanceMap[option.paired][option.owner];
        UserBalance storage otiU = userBalanceMap[option.token][option.owner];
        UserBalance storage tti = userBalanceMap[option.paired][option.taker];
        UserBalance storage ttiU = userBalanceMap[option.token][option.taker];
        UserBalance storage ccBT = userBalanceMap[option.paired][address(this)];
        UserBalance storage ccUT = userBalanceMap[option.token][address(this)];
        UserBalance storage minrT = userBalanceMap[option.token][msg.sender];
        UserBalance storage minrB = userBalanceMap[option.paired][msg.sender];

        hedgeInfo.newAddressFlag = ttiU.deposited == 0;

        // Settlement logic for CALLs
        if (option.hedgeType == HedgeType.CALL) {
            hedgeInfo.marketOverStart = hedgeInfo.underlyingValue > option.strikeValue + option.cost;
            if (hedgeInfo.marketOverStart) {
                // Taker profit in pair currency = underlying - cost - strike value
                // Convert to equivalent tokens lockedInUse by owner, factor fee
                // Check if collateral is enough, otherwise use max balance from Owner lockedInUse
                hedgeInfo.payOff = hedgeInfo.underlyingValue - (option.strikeValue + option.cost);
                (hedgeInfo.priceNow,) = getUnderlyingValue(option.token, 1);
                hedgeInfo.tokensDue = hedgeInfo.payOff / hedgeInfo.priceNow;
                if (otiU.lockedInUse < hedgeInfo.tokensDue) {
                    hedgeInfo.tokensDue = otiU.lockedInUse;
                }
                hedgeInfo.tokenFee = calculateFee(hedgeInfo.tokensDue);
                // Move payoff - in underlying, take payoff from owner, credit taxed payoff to taker, finalize owner loss
                ttiU.deposited += hedgeInfo.tokensDue - hedgeInfo.tokenFee;
                otiU.lockedInUse -= option.amount - hedgeInfo.tokensDue;
                otiU.withdrawn += hedgeInfo.tokensDue;
                // Restore taker collateral from lockedInUse - not applicable, taker won & cost was paid to owner
                //
                // Move fees - credit taxes in both, as profit is in underlying and cost is in pair
                ccUT.deposited += (hedgeInfo.tokenFee * protocolFeeRate) / 100;
                // Miner fee - X% of protocol fee for settling option. Mining call options always come with 2 token fees
                minrT.deposited += (hedgeInfo.tokenFee * validatorFeeRate) / 100;
                // Log wallet PL: 0 - owner won, 1 taker won
                logPL(hedgeInfo.payOff - calculateFee(hedgeInfo.payOff), option.paired, option.owner, option.taker, 1);
            } else {
                // Move payoff - owner wins cost & losses nothing. Mining not required as cost already paid to writer
                // Restore winners collateral - underlying to owner. none to taker.
                oti.lockedInUse -= option.amount;
                // Log wallet PL: 0 - owner won, 1 taker won
                logPL(option.cost, option.paired, option.owner, option.taker, 0);
            }
        }
        // Settlement logic for PUTs
        else if (option.hedgeType == HedgeType.PUT) {
            hedgeInfo.isBelowStrikeValue = option.strikeValue > hedgeInfo.underlyingValue + option.cost;
            if (hedgeInfo.isBelowStrikeValue) {
                // Taker profit in paired = underlying value - strike value
                // Convert to equivalent tokens lockedInUse by writer, factor fee
                // Check if writer collateral is enough, otherwise use max balance from writer lockedInUse
                hedgeInfo.payOff = option.strikeValue - hedgeInfo.underlyingValue + option.cost;
                (hedgeInfo.priceNow,) = getUnderlyingValue(option.token, 1);
                hedgeInfo.tokensDue = hedgeInfo.payOff / hedgeInfo.priceNow;
                if (otiU.lockedInUse < hedgeInfo.tokensDue) {
                    hedgeInfo.tokensDue = otiU.lockedInUse;
                }
                // Get protocol settlement fee in tokens
                hedgeInfo.tokenFee = calculateFee(hedgeInfo.tokensDue);
                // Move payoff - in underlying, take payoff from writer, credit taxed payoff to taker, finalize writer loss
                otiU.lockedInUse -= option.amount - hedgeInfo.tokensDue;
                ttiU.deposited += hedgeInfo.tokensDue - hedgeInfo.tokenFee;
                otiU.withdrawn += hedgeInfo.tokensDue;
                // Restore taker collateral from lockedInUse - not applicable, taker won & cost already paid to owner
                // Move fees - credit taxes in both, as profit is in underlying and cost is in paired
                ccUT.deposited += (hedgeInfo.tokenFee * protocolFeeRate) / 100;
                minrT.deposited += (hedgeInfo.tokenFee * validatorFeeRate) / 100;
                logPL(hedgeInfo.payOff - calculateFee(hedgeInfo.payOff), option.paired, option.owner, option.taker, 1);
            } else {
                // Writer wins cost & losses nothing. Mining not required as cost already paid to writer
                // Restore winners collateral - underlying to owner. none to taker
                oti.lockedInUse -= option.amount;
                logPL(option.cost, option.paired, option.owner, option.taker, 0);
            }
        }
        // Settlement logic for SWAP
        else if (option.hedgeType == HedgeType.SWAP) {
            // if price if higher than start, payoff in token to taker
            // if price is lower than start, payoff in paired token to writer
            if (hedgeInfo.underlyingValue > option.startValue) {
                hedgeInfo.payOff = hedgeInfo.underlyingValue - option.startValue;
                // Convert payoff to token equivalent
                (hedgeInfo.priceNow,) = getUnderlyingValue(option.token, 1);
                hedgeInfo.tokensDue = hedgeInfo.payOff / hedgeInfo.priceNow;
                // Use all tokens if token amount is not enough to cover payoff
                if (hedgeInfo.tokensDue > option.amount) {
                    hedgeInfo.tokensDue = option.amount;
                }
                // Get protocol settlement fee in tokens. EquitySwaps vary in payoff unlike options where its always = hedge cost
                hedgeInfo.tokenFee = calculateFee(hedgeInfo.tokensDue);
                // Move payoff - in underlying, take full gains from writer, credit taxed amount to taker, pocket difference
                ttiU.deposited += hedgeInfo.tokensDue - hedgeInfo.tokenFee;
                otiU.lockedInUse -= option.amount;
                otiU.withdrawn += hedgeInfo.tokensDue;
                // Restore winner collateral - for taker restore cost (swaps have no premium)
                tti.lockedInUse -= option.cost;
                // Move fees - take taxes from profits in underlying. none in paired because taker won underlying tokens
                ccUT.deposited += (hedgeInfo.tokenFee * protocolFeeRate) / 100;
                // Miner fee - X% of protocol fee for settling option. none in paired because taker won underlying tokens
                minrT.deposited += (hedgeInfo.tokenFee * validatorFeeRate) / 100;
                logPL(hedgeInfo.payOff - calculateFee(hedgeInfo.payOff), option.paired, option.owner, option.taker, 0);
            } else {
                hedgeInfo.payOff = option.startValue - hedgeInfo.underlyingValue;
                // Use all cost if paired token amount is not enough to cover payoff
                if (hedgeInfo.payOff > option.cost) {
                    hedgeInfo.payOff = option.cost;
                }
                // Get protocol settlement fee in paired currency. [EquitySwaps vary in payoff unlike options where its always = hedge cost]
                hedgeInfo.pairedFee = calculateFee(hedgeInfo.payOff);
                // Move payoff - loss of paired cost to taker only, writer loses nothing
                // 1. credit equivalent payoff in paired to writer
                // 2. credit takers full cost back & then debit loss using withrawn instantly
                oti.deposited += hedgeInfo.payOff - hedgeInfo.pairedFee;
                tti.lockedInUse -= option.cost;
                tti.withdrawn += hedgeInfo.payOff;
                // Restore winner collateral - for owner, all underlying tokens
                otiU.lockedInUse -= option.amount;
                // Move fees - profits in pair so only paired fees credited
                ccBT.deposited += (hedgeInfo.pairedFee * protocolFeeRate) / 100;
                // Miner fee - X% of protocol fee for settling option. none in underlying tokens
                minrB.deposited += (hedgeInfo.pairedFee * validatorFeeRate) / 100;
                logPL(hedgeInfo.payOff, option.paired, option.owner, option.taker, 1);
            }
        }

        option.status = 3;
        option.endValue = hedgeInfo.underlyingValue;
        option.dt_settled = block.timestamp;

        if (option.hedgeType == HedgeType.CALL || option.hedgeType == HedgeType.PUT) {
            optionsSettled[option.token].push(_dealID);
        }
        if (option.hedgeType == HedgeType.SWAP) {
            equityswapsSettled[option.token].push(_dealID);
        }
        logMiningData(msg.sender);
        logAnalyticsFees(
            option.token,
            hedgeInfo.tokenFee + hedgeInfo.pairedFee + hedgeInfo.tokensDue, // aggregated fees
            option.cost,
            hedgeInfo.underlyingValue
        );

        // Catch new erc20 address so that wallet can log all underlying token balances credited to it
        // Paired addresses already caught on deposit by wallet
        if (hedgeInfo.tokensDue > 0 && hedgeInfo.newAddressFlag) {
            userERC20s[option.taker].push(option.token);
        }

        emit HedgeSettled(option.token, _dealID, hedgeInfo.underlyingValue, hedgeInfo.payOff, msg.sender);
        emit MinedHedge(_dealID, msg.sender, option.token, option.paired, hedgeInfo.tokenFee, hedgeInfo.pairedFee);
    }

    //=============== INTERNAL METHODS ===============//
    /**
     * @notice Logs mining data when a trade settles.
     *
     * This function increments the settled trades count and updates the miner count if the miner is new.
     *
     * @param miner The address of the miner.
     */
    function logMiningData(address miner) internal {
        settledTradesCount++;
        if (!minerMap[miner]) {
            minerMap[miner] = true;
            miners++;
        }
    }

    /**
     * @notice Logs analytics and fees data after a settlement.
     *
     * This function updates the protocol profits, fees, and paired fees after a settlement.
     * hack: simplified for testnet
     *
     * @param token The address of the token.
     * @param tokenFee The fee collected in the token.
     * @param tokenProfit The profit made in the token.
     * @param endValue The end value of the settlement.
     */
    function logAnalyticsFees(address token, uint256 tokenFee, uint256 tokenProfit, uint256 endValue) internal {
        // All profits made by traders
        protocolProfitsTokens[token] += tokenProfit;

        // Fees collected by protocol
        protocolFeesTokens[token] += tokenFee;

        // Since all tokens are paired with WETH, update WETH-based tracking
        protocolPairProfits[wethAddress] += tokenProfit;
        protocolPairedFees[wethAddress] += tokenFee;
        settledVolume[wethAddress] += endValue;
    }

    /**
     * @notice Logs profit and loss (PL) data after a settlement.
     *
     * This function updates the profit and loss data for the involved parties after a settlement.
     *
     * @param amount The amount of profit or loss.
     * @param paired The address of the paired token.
     * @param optionowner The address of the option owner.
     * @param optiontaker The address of the option taker.
     * @param winner Indicates whether the option owner (0) or taker (1) is the winner.
     */
    function logPL(uint256 amount, address paired, address optionowner, address optiontaker, uint256 winner) internal {
        if (winner == 0) {
            userPLMap[paired][optionowner].profits += amount;
            userPLMap[paired][optiontaker].losses += amount;
        } else if (winner == 1) {
            userPLMap[paired][optiontaker].profits += amount;
            userPLMap[paired][optionowner].losses += amount;
        }
    }

    //=============== ETHER HANDLING ===============//
    // hack: not needed for testnet, removed to keep contract under size limit (24576)
    // receive() external payable {
    //     emit Received(msg.sender, msg.value);
    // }

    // function withdrawEther(address payable to, uint256 amount) external onlyOwner nonReentrant {
    //     require(to != address(0), "Invalid address");
    //     require(amount > 0, "Amount must be greater than 0");
    //     require(address(this).balance >= amount, "Insufficient balance");

    //     (bool success,) = to.call{value: amount}("");
    //     require(success, "Transfer failed");

    //     emit EtherWithdrawn(to, amount);
    // }
}
