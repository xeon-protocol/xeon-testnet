// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "./XeonStructs.sol";

/**
 * @title XeonStorage Contract
 * @author Jon Bray <jon@xeon-protocol.io>
 * @dev Storage for state variables and mappings used by Xeon Protocol
 */
contract XeonStorage {
    using XeonStructs for XeonStructs.UserBalance;
    using XeonStructs for XeonStructs.HedgingOption;
    /* todo: declare virtual variables as needed */
    // update visibility through codebase
    // private - only callable from inside contract
    // internal - callable inside contract + child contracts
    // public - callable inside + outside contract
    // external - only callable from outside contract
    //=============== STATE VARIABLES ===============//

    uint256[] internal optionsCreated;
    uint256[] internal equityswapsCreated;
    uint256[] internal optionsTaken;
    uint256[] internal equityswapsTaken;

    uint256 public dealId;
    uint256 public topupRequestId;

    uint256 public depositedTokensLength;
    uint256 public optionsCreatedLength;
    uint256 public equityswapsCreatedLength;
    uint256 public equityswapsTakenLength;
    uint256 public optionsTakenLength;

    uint256 public settledTradesCount;
    uint256 public miners;

    uint256 public wethEquivDeposits;
    uint256 public wethEquivWithdrawals;

    //=============== MAPPINGS ===============//
    mapping(address => XeonStructs.ContractBalance) public protocolBalanceMap;
    mapping(uint256 => XeonStructs.HedgingOption) internal hedgeMap;
    mapping(uint256 => XeonStructs.TopupData) public topupMap;
    mapping(address => uint256[]) internal tokenOptions;
    mapping(address => uint256[]) internal tokenSwaps;
    mapping(address => uint256[]) internal optionsBought;
    mapping(address => uint256[]) internal optionsSettled;
    mapping(address => uint256[]) internal equityswapsBought;
    mapping(address => uint256[]) internal equityswapsSettled;
    mapping(address => address[]) public userERC20s;
    mapping(address => address[]) public pairedERC20s;

    mapping(address => XeonStructs.ProtocolAnalytics) public protocolAnalyticsMap;
    mapping(address => uint256) public protocolCashierFees;

    mapping(address => mapping(address => XeonStructs.UserBalance)) public userBalanceMap;
    mapping(address => mapping(address => XeonStructs.UserPnL)) internal userPnLMap;
    mapping(address => mapping(address => uint256[])) internal userHedgesForTokenMap;
    mapping(address => mapping(address => uint256)) public equivUserHedged;
    mapping(address => mapping(address => uint256)) public equivUserCosts;

    // Mappings of user hedge-related data
    mapping(address => uint256[]) public userOptionsCreated;
    mapping(address => uint256[]) public userOptionsTaken;
    mapping(address => uint256[]) public userSwapsCreated;
    mapping(address => uint256[]) public userSwapsTaken;

    // Mappings of miner data
    mapping(address => bool) public minerMap;
}
