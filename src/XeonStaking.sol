// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./XeonFeeManagement.sol";
import "./XeonStorage.sol";
import "./XeonStructs.sol";
import "./XeonToken.sol";

/**
 * @title Xeon Staking
 * @author Jon Bray <jon@xeon-protocol.io>
 * @notice stake XEON for stXEON on chosen chain
 * @dev uses CCIP to route stXEON to a chosen chain
 */
contract XeonStaking is Ownable(msg.sender), ReentrancyGuard {}
