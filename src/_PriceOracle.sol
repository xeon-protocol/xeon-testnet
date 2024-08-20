// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;
// pragma solidity 0.6.6; // univ2 requirement
// pragma solidity 0.7.6; // univ3 requirement

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title Xeon Price Oracle
 * @author Jon Bray <jon@xeon-protocol.io>
 * @notice onchain price oracle for Xeon Protocol
 * @dev utilize TWAP + ChainLink
 */
contract PriceOracle {
    AggregatorV3Interface interface chainLinkPriceFeed;

    constructor() {
        // ETH-USD
        chainLinkPriceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    }

    /* todo: decimal logic
    ** get decimals
    ** get price
    ** ensure scalled correctly
    */
}

// initialize ChainLink aggregator
// interface AggregatorV3Interface {
//     function latestRoundData()
//         external
//         view
//         returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
// }
