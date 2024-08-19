// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./PriceOracle.sol";
import "./XeonFeeManagement.sol";
import "./XeonStorage.sol";
import "./XeonStructs.sol";

interface IPriceOracle {
    function getValueInWETH(address token) external view returns (uint256);
    function setTokenPriceInWETH(address token, uint256 priceInWETH) external;
    function setWETHPriceInUSD(uint256 priceInUSD) external;
}

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
contract XeonHedging is Ownable(msg.sender), ReentrancyGuard {}
