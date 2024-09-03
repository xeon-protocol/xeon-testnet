// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IPriceOracle {
    function getUnderlyingValue(address token) external view returns (uint256);
}

interface IXeonStaking {
/* todo: add relevant functions to staking */
}

contract XeonHedging_Test_VNext is Ownable(msg.sender), ReentrancyGuard, ERC721Enumerable {
    using SafeERC20 for IERC20;

    address public admin;
    address public owner;
    address public stakingPool;
    address public priceOracle;

    /* todo: wrap hedging structs in the NFT position */
    struct hedgingOption {
        address maker;
        address taker;
        address collateralToken;
        address pairedToken;
        uint256 hedgeStatus; // 0 - none, 1 - created, 2 - taken, 3 - settled
            /* todo: add relevant fields */
    }

    /* todo: these should be part of NFT position */
    enum HedgeType {
        CALL,
        PUT,
        SWAP
    }

    //========== HEDGE MANAGEMENT ==========//
    /**
     * @dev create a new hedge, which can be a call option, put option, or equity swap
     * the cost is in a paired currency, for ETH use address=0
     *
     * params:
     * - trigger internal function dependent on type of hedge (_newCallOption, _newPutOption, _newEquitySwap)
     * - address of token being used as collateral
     * - amount of the collateral token
     * - cost in units of paired token (set by user)
     * - strike price in paired token (set by user)
     * - expiration timestamp of the option (set by user)
     *
     */
    function createHedge() external nonReentrant {
        /* todo: add relevant code */
    }

    /**
     * @dev create a new equity swap
     * the user puts collateral in the option and requests a swap
     *
     * params:
     * - address of token being used as collateral
     * - amount of the collateral token
     * - expiration timestamp of the option (set by user)
     */
    function createSwap() external nonReentrant {
        /* todo: add relevant code */
    }

    /**
     * @dev allows another user to purchase a call option or put option or equity swap
     * cost is in the paired currency of the underlying token
     * cost is locked in the position token along with collateral
     * for equity swaps, the cost must be equal to the underlying value (100% collateral required)
     *
     * requirements:
     * - hedge must be available (status = 1)
     * - hedge must not be expired
     * - caller must not be the hedge creator
     * - caller must have sufficient balance of requested token
     * - the dealId must not have already been purchased
     *
     * - emit a {HedgePurchased} event
     *
     * param: _dealId of the hedge to be purchased
     */
    function buyHedge(uint256 _dealId) external nonReentrant {
        /* todo: add relevant code */
    }

    /**
     * @dev delete an untaken, unexercised, or expired hedge
     * only the hedge creator or the staking pool can delete the hedge
     * and it must meet the required conditions
     *
     * conditions:
     * - the creator can only delete an untaken hedge before it is taken (status = 1)
     * - the staking pool can delete the hedge after it expires and if it remains unexcersied (status != 3)
     * - the staking pool can delete an expired and unexercised hedge (status = 2)
     * - if staking pool deletes the hedge, it receives a fee for doing so
     * - equity swaps (HedgeType.SWAP) cannot be deleted once taken, only settled
     * - upon deletion, the remaining balance after fees is restored to the hedge creator
     *
     * requirements:
     * - the hedge must be in a valid state for deletion (status = 1 or status = 2)
     * - the caller must be the creator if the hedge is untaken (status = 1)
     * - the caller must be the staking pool if the hedge is expired and unexcersied (status = 2)
     * - the hedge must be expired if a miner is deleting it
     * - equity swaps (HedgeType.SWAP) cannot be deleted if taken
     *
     * @param _dealId of the hedge to be deleted
     */
    function deleteHedge(uint256 _dealId) external nonReentrant {
        /* todo: add relevant code based on conditions and requirements */
    }

    /**
     * @dev settle a hedge that has been taken and reached expiry
     *
     * conditions:
     * - only authorized parties can settle a hedge: creator, taker, or staking pool
     * - only the taker can settle before expiry
     * - only the staking pool or creator can settle after expiry
     * - if hedge meets requirements to be deleted, delete it
     *
     * @param _dealId of the hedge to be settled
     */
    function settleHedge(uint256 _dealId) external nonReentrant {
        /* todo: add relevant code to settle a specific hedge that has been taken and reached expiry */
    }

    /**
     * @dev same conditions as `settleHedge` but in bulk
     */
    function settleAllHedges() external nonReentrant {
        /* todo: add relevant code to settle all hedges that have been taken and reached expiry */
    }

    //========== FEE MANAGEMENT ==========//
    /**
     * @dev transfer protocol fees to the staking pool whenever a hedge is settled
     *
     * requirements:
     * - address of the token being transferred
     * - address of the staking pool
     * - amount of feed to be transferred
     *
     * - emit {FeesTransferred} event
     */
    function _transferProtocolFees() internal {
        /* todo: add relevant code */
    }
}
