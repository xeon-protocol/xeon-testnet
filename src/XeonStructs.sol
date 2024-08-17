// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title XeonStructs Library
 * @author Jon Bray <jon@xeon-protocol.io>
 * @notice this is a library of structs used throughout Xeon Protocol
 */
library XeonStructs {
    /**
     * @dev Stores user balance information, including deposited, withdrawn, and locked amounts.
     */
    struct UserBalance {
        uint256 deposited;
        uint256 withdrawn;
        uint256 lockedInUse;
    }

    /**
     * @dev Stores contract balance information, including total deposited and withdrawn amounts.
     */
    struct ContractBalance {
        uint256 deposited;
        uint256 withdrawn;
    }

    /**
     * @dev Contains detailed information for hedging calculations, including payoffs and fees.
     */
    struct HedgeInfo {
        uint256 underlyingValue;
        uint256 payOff;
        uint256 priceNow;
        uint256 tokensDue;
        uint256 tokenFee;
        uint256 pairedFee;
        bool marketOverStart;
        bool isBelowStrikeValue;
        bool newAddressFlag;
    }

    /**
     * @dev Stores information about a token pair, including reserve amounts and decimals.
     */
    struct PairInfo {
        address pairAddress;
        address pairedCurrency;
        IERC20 token0;
        IERC20 token1;
        uint112 reserve0;
        uint112 reserve1;
        uint256 token0Decimals;
        uint256 token1Decimals;
    }

    /**
     * @dev Represents a hedging option with all its associated data.
     */
    struct HedgingOption {
        bool zapTaker;
        bool zapWriter;
        address owner;
        address taker;
        address token;
        address paired;
        uint256 status; // 0 - none, 1 - created, 2 - taken, 3 - settled
        uint256 amount;
        uint256 createValue;
        uint256 startValue;
        uint256 strikeValue;
        uint256 endValue;
        uint256 cost;
        uint256 dt_created;
        uint256 dt_started;
        uint256 dt_expiry;
        uint256 dt_settled;
        HedgeType hedgeType;
        uint256[] topupRequests;
    }

    /**
     * @dev Tracks a user's profit and loss for a specific pair.
     */
    struct UserPL {
        uint256 profits;
        uint256 losses;
    }

    /**
     * @dev Contains data for top-up requests within a hedging option.
     */
    struct TopupData {
        address requester;
        uint256 amountWriter;
        uint256 amountTaker;
        uint256 requestTime;
        uint256 acceptTime;
        uint256 rejectTime;
        uint256 state; // 0 - requested, 1 accepted, 2 rejected
    }

    /**
     * @dev Represents different types of hedging options available in the protocol.
     */
    enum HedgeType {
        CALL,
        PUT,
        SWAP
    }
}
