// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Minimal interface for WETH token interactions
interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function withdraw(uint256) external;
}

// Interface for the price oracle
interface IPriceOracle {
    function getValueInWETH(address token) external view returns (uint256);
    function setTokenPriceInWETH(address token, uint256 priceInWETH) external;
    function setWETHPriceInUSD(uint256 priceInUSD) external;
}

/**
 * @title XeonHedging Test V3 - hedging logic for PUT, CALL, and SWAP options
 * @notice this is a testnet version of XeonHedging and should not be used in production
 * @author Jon Bray <jon@xeon-protocol.io>
 * @author ByteZero <bytezero@xeon-protocol.io>
 */
contract XeonHedging_Test_V3 is ReentrancyGuard, ERC721URIStorage, Ownable {
    using SafeERC20 for IERC20;

    //========== ENUMS ==========//
    enum HedgeType {
        CALL,
        PUT,
        SWAP
    }

    //========== STRUCTS ==========//
    struct Hedge {
        address writer;
        address taker;
        address collateralToken;
        uint256 collateralAmount;
        uint256 strikePrice;
        uint256 expiry;
        uint256 cost; // premium or cost to buy hedge, quoted in paired currency
        HedgeType hedgeType;
        bool isExercised;
        bool isSettled;
    }

    //========== STATE VARIABLES ==========//
    uint256 public nextHedgeId = 1; // Initialize hedgeIdCounter to 1 to skip 0
    address public wethAddress; // network-specific WETH address
    address public priceOracleAddress; // Price oracle contract address
    address public stakingPoolAddress; // Staking pool address
    address public admin; // Admin address for contract ownership

    uint256 public collateralFeeNumerator = 50; // 0.5% fee for collateral
    uint256 public purchaseFeeNumerator = 100; // 1% fee for purchasing hedge
    uint256 public feeDenominator = 10000; // Denominator for percentage calculations

    //========== MAPPINGS ==========//
    mapping(uint256 => Hedge) public hedges;

    //========== EVENTS ==========//
    event HedgeCreated(
        uint256 indexed hedgeId,
        address indexed writer,
        HedgeType hedgeType,
        uint256 amount,
        uint256 strikePrice,
        uint256 expiry,
        uint256 cost
    );
    event HedgeTaken(uint256 indexed hedgeId, address indexed taker);
    event HedgeExercised(uint256 indexed hedgeId, address indexed taker, uint256 payoff);
    event HedgeSettled(uint256 indexed hedgeId, address indexed writer, address indexed taker);
    event HedgeDeleted(uint256 indexed hedgeId);
    event ProtocolFeesUpdated(uint256 collateralFeeNumerator, uint256 purchaseFeeNumerator, uint256 feeDenominator);

    //========== CONSTRUCTOR ==========//
    constructor(address _wethAddress, address _priceOracleAddress, address _stakingPoolAddress, address _admin)
        ERC721("Xeon Hedge Position v1", "XEON-V1-POS")
        Ownable(_admin)
    {
        wethAddress = _wethAddress;
        priceOracleAddress = _priceOracleAddress;
        stakingPoolAddress = _stakingPoolAddress;
        admin = _admin;

        // Set the initial owner to the admin address
        transferOwnership(_admin);
    }

    //========== HEDGING FUNCTIONS ==========//
    function createHedge(
        address token,
        uint256 amount,
        uint256 strikePrice,
        uint256 expiry,
        uint256 cost,
        HedgeType hedgeType
    ) external nonReentrant returns (uint256 hedgeId) {
        require(amount > 0, "Invalid amount");
        require(expiry > block.timestamp, "Invalid expiry");
        require(cost > 0, "Invalid cost");

        // Fetch the current market value of the token in WETH
        uint256 marketValue = IPriceOracle(priceOracleAddress).getValueInWETH(token);

        if (hedgeType == HedgeType.CALL) {
            require(strikePrice > marketValue, "Strike price must be greater than market value for CALL");
        } else if (hedgeType == HedgeType.PUT) {
            require(strikePrice < marketValue, "Strike price must be less than market value for PUT");
        }

        // Calculate collateral fee
        uint256 collateralFee = (amount * collateralFeeNumerator) / feeDenominator;
        uint256 netCollateralAmount = amount - collateralFee;

        // Transfer collateral and fee to the contract and staking pool
        IERC20(token).safeTransferFrom(msg.sender, address(this), netCollateralAmount);
        IERC20(token).safeTransferFrom(msg.sender, stakingPoolAddress, collateralFee);

        // Create hedge with net collateral amount
        hedgeId = nextHedgeId++;
        hedges[hedgeId] = Hedge({
            writer: msg.sender,
            taker: address(0),
            collateralToken: token,
            collateralAmount: netCollateralAmount,
            strikePrice: strikePrice,
            expiry: expiry,
            cost: cost,
            hedgeType: hedgeType,
            isExercised: false,
            isSettled: false
        });

        _mint(msg.sender, hedgeId);

        emit HedgeCreated(hedgeId, msg.sender, hedgeType, netCollateralAmount, strikePrice, expiry, cost);
    }

    function takeHedge(uint256 hedgeId, uint256 takerAmount) external nonReentrant {
        Hedge storage hedge = hedges[hedgeId];

        require(hedge.writer != address(0), "Invalid hedge ID");
        require(hedge.taker == address(0), "Hedge already taken");
        require(block.timestamp < hedge.expiry, "Hedge expired");
        require(msg.sender != hedge.writer, "Hedge owner cannot take their own hedge");

        if (hedge.hedgeType == HedgeType.SWAP) {
            // Get the value of the writer's collateral in WETH
            uint256 writerCollateralValueInWETH =
                IPriceOracle(priceOracleAddress).getValueInWETH(hedge.collateralToken) * hedge.collateralAmount;

            // Get the value of the taker's collateral in WETH
            uint256 takerCollateralValueInWETH =
                IPriceOracle(priceOracleAddress).getValueInWETH(hedge.collateralToken) * takerAmount;

            require(
                takerCollateralValueInWETH >= writerCollateralValueInWETH,
                "Taker's collateral must be equal to or greater than the writer's collateral"
            );

            // Transfer the taker's collateral to the contract
            IERC20(hedge.collateralToken).safeTransferFrom(msg.sender, address(this), takerAmount);
        }

        // Calculate purchase fee
        uint256 purchaseFee = (hedge.cost * purchaseFeeNumerator) / feeDenominator;
        uint256 netPurchasePrice = hedge.cost - purchaseFee;

        // Transfer the net purchase price to the writer and the fee to the staking pool
        IERC20(wethAddress).safeTransferFrom(msg.sender, hedge.writer, netPurchasePrice);
        IERC20(wethAddress).safeTransferFrom(msg.sender, stakingPoolAddress, purchaseFee);

        // Assign the taker
        hedge.taker = msg.sender;

        emit HedgeTaken(hedgeId, msg.sender);
    }

    /**
     * @dev handle the exercise of a CALL or PUT option by the taker before expiry
     * CALL Option: ensure market value (from oracle) is greater than the strike price
     * before allowing the taker to exercise the option. Payoff is the collateral amount,
     * which is transferred to the taker.
     *
     * PUT Option: ensure the market value is less than the strike price.
     * Payoff is the strike price, is transferred to the writer in WETH.
     *
     * @param hedgeId token Id of the option
     */
    function exerciseHedge(uint256 hedgeId) external nonReentrant {
        Hedge storage hedge = hedges[hedgeId];
        require(hedge.taker == msg.sender, "Only the taker can exercise this hedge");
        require(block.timestamp < hedge.expiry, "Hedge expired");
        require(!hedge.isExercised, "Hedge already exercised");

        uint256 payoff;

        if (hedge.hedgeType == HedgeType.CALL) {
            uint256 currentValue = IPriceOracle(priceOracleAddress).getValueInWETH(hedge.collateralToken);
            require(currentValue > hedge.strikePrice, "Strike price must be less than market value to exercise");

            payoff = hedge.collateralAmount; // Payoff in underlying asset
            IERC20(hedge.collateralToken).safeTransfer(hedge.taker, payoff);
        } else if (hedge.hedgeType == HedgeType.PUT) {
            uint256 currentValue = IPriceOracle(priceOracleAddress).getValueInWETH(hedge.collateralToken);
            require(currentValue < hedge.strikePrice, "Strike price must be greater than market value to exercise");

            payoff = hedge.strikePrice; // Payoff in paired currency
            IWETH(wethAddress).transfer(hedge.writer, payoff);
        }

        hedge.isExercised = true;

        emit HedgeExercised(hedgeId, msg.sender, payoff);
    }

    /**
     * @dev handle settlement of a hedge after expiry. For PUT and CALL options,
     * only the staking pool or taker can settle.
     *
     * CALL/PUT options: these can only be settled by the staking pool or taker
     * after expiry. if the option was not exercised, the collateral is returned
     * to the writer.
     *
     * SWAP: calculate the payoff based on the difference between the market
     * value and strike price. if the collateral is insufficient to pay the winner,
     * all available collateral is paid.
     *
     * @param hedgeId token Id of the option
     */
    function settleHedge(uint256 hedgeId) external nonReentrant {
        Hedge storage hedge = hedges[hedgeId];
        require(block.timestamp >= hedge.expiry, "Hedge not expired");
        require(!hedge.isSettled, "Hedge already settled");

        uint256 payoff;

        if (hedge.hedgeType == HedgeType.SWAP) {
            uint256 currentValue = IPriceOracle(priceOracleAddress).getValueInWETH(hedge.collateralToken);

            if (currentValue > hedge.strikePrice) {
                payoff = currentValue - hedge.strikePrice;
                IERC20(hedge.collateralToken).safeTransfer(hedge.taker, payoff);
            } else {
                payoff = hedge.strikePrice - currentValue;
                uint256 collateralAvailable = IERC20(hedge.collateralToken).balanceOf(address(this));
                uint256 payout = (collateralAvailable >= payoff) ? payoff : collateralAvailable;
                IWETH(wethAddress).transfer(hedge.writer, payout);
            }
        } else {
            require(msg.sender == hedge.taker || msg.sender == stakingPoolAddress, "Unauthorized to settle hedge");

            if (!hedge.isExercised) {
                uint256 collateralAmount = hedge.collateralAmount;
                IERC20(hedge.collateralToken).safeTransfer(hedge.writer, collateralAmount);
            }
        }

        hedge.isSettled = true;

        emit HedgeSettled(hedgeId, hedge.writer, hedge.taker);
    }

    /**
     * @dev handle the deletion of expired and unexercised hedges
     *
     * this function checks if the hedge has expired and wasn't exercised.
     * if the staking pool deletes the hedge, a fee is deducted before returning
     * the collateral to the writer. if the writer deletes it, they receive the full
     * collateral.
     *
     * @param hedgeId token Id of the option
     */
    function deleteExpiredHedge(uint256 hedgeId) external nonReentrant {
        Hedge storage hedge = hedges[hedgeId];
        require(block.timestamp >= hedge.expiry, "Hedge not expired");
        require(!hedge.isSettled, "Hedge already settled");

        if (!hedge.isExercised && hedge.taker == address(0)) {
            // If staking pool is closing the hedge, apply a 1% fee to the writer
            if (msg.sender == stakingPoolAddress) {
                uint256 closureFee = (hedge.collateralAmount * purchaseFeeNumerator) / feeDenominator;
                uint256 remainingCollateral = hedge.collateralAmount - closureFee;

                // Transfer the fee to the staking pool
                IERC20(hedge.collateralToken).safeTransfer(stakingPoolAddress, closureFee);
                // Return remaining collateral to the writer
                IERC20(hedge.collateralToken).safeTransfer(hedge.writer, remainingCollateral);
            } else {
                // Return full collateral to the writer if they are closing the hedge
                IERC20(hedge.collateralToken).safeTransfer(hedge.writer, hedge.collateralAmount);
            }
        }

        hedge.isSettled = true;

        emit HedgeDeleted(hedgeId);
    }

    //========== FEE MANAGEMENT FUNCTIONS ==========//

    function updateProtocolFees(uint256 _collateralFeeNumerator, uint256 _purchaseFeeNumerator, uint256 _feeDenominator)
        external
        onlyOwner
    {
        require(_feeDenominator > 0, "Fee denominator must be greater than 0");
        require(_collateralFeeNumerator <= _feeDenominator, "Invalid collateral fee");
        require(_purchaseFeeNumerator <= _feeDenominator, "Invalid purchase fee");

        collateralFeeNumerator = _collateralFeeNumerator;
        purchaseFeeNumerator = _purchaseFeeNumerator;
        feeDenominator = _feeDenominator;

        emit ProtocolFeesUpdated(_collateralFeeNumerator, _purchaseFeeNumerator, _feeDenominator);
    }

    //========== VIEW FUNCTIONS ==========//

    function getCollateral(uint256 hedgeId) external view returns (address collateralToken, uint256 collateralAmount) {
        Hedge storage hedge = hedges[hedgeId];
        collateralToken = hedge.collateralToken;
        collateralAmount = hedge.collateralAmount;
    }

    function getExpiryTime(uint256 hedgeId) external view returns (uint256 expiryTime) {
        Hedge storage hedge = hedges[hedgeId];
        expiryTime = hedge.expiry;
    }
}
