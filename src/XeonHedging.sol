// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; // NFT support
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol"; // Enumerable extension for NFTs

/* todo: update to new chainlink enabled price oracle */
interface IPriceOracle {
    function getValueInWETH(address token) external view returns (uint256);
    function setTokenPriceInWETH(address token, uint256 priceInWETH) external;
    function setWETHPriceInUSD(uint256 priceInUSD) external;
}

/* todo: update to new staking contract */
interface IXeonStaking {}

/**
 * @title Xeon Hedging
 * @author Jon Bray <jon@xeon-protocol.io>
 * @notice this is a testnet version of XeonHedging and should not be used in production
 */
// todo: not
abstract contract XeonHedging is Ownable(msg.sender), ReentrancyGuard, ERC721Enumerable {
    using SafeERC20 for IERC20;
}
