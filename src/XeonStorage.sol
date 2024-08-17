// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./XeonStructs.sol";

contract XeonStorage {
    using XeonStructs for XeonStructs.UserBalance;
    using XeonStructs for XeonStructs.HedgingOption;

    //=============== STATE VARIABLES ===============//
    uint256[] private optionsCreated;
    uint256[] private equityswapsCreated;
    uint256[] private optionsTaken;
    uint256[] private equityswapsTaken;
    uint256 public dealID;
    uint256 public topupRequestID;

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
    // mapping of wallet token balances [token][user]
    mapping(address => mapping(address => XeonStructs.UserBalance)) public userBalanceMap;

    //mapping of user-hedge-Ids array for each erc20 token
    mapping(address => mapping(address => uint256[])) private userHedgesForTokenMap;

    // mapping of wallet profit & loss [pair][user]
    mapping(address => mapping(address => XeonStructs.UserPL)) private userPLMap;

    // track all erc20 deposits and withdrawals to contract
    mapping(address => XeonStructs.ContractBalance) public protocolBalanceMap;

    // mapping of all hedge storages by Id
    mapping(uint256 => XeonStructs.HedgingOption) private hedgeMap;

    // mapping topup requests
    mapping(uint256 => XeonStructs.TopupData) public topupMap;

    // mapping of all deals created for each erc20
    mapping(address => uint256[]) private tokenOptions;
    mapping(address => uint256[]) private tokenSwaps;

    // mapping of all deals taken for each erc20
    mapping(address => uint256[]) private optionsBought;
    mapping(address => uint256[]) private equityswapsBought;

    // mapping of all deals settled for each erc20
    mapping(address => uint256[]) private optionsSettled;
    mapping(address => uint256[]) private equityswapsSettled;

    // mapping of all deals for user by Id
    mapping(address => uint256[]) public myoptionsCreated;
    mapping(address => uint256[]) public myoptionsTaken;
    mapping(address => uint256[]) public myswapsCreated;
    mapping(address => uint256[]) public myswapsTaken;

    // mapping of all tokens transacted by user
    mapping(address => address[]) public userERC20s;
    mapping(address => address[]) public pairedERC20s;

    // mapping of all protocol profits and fees collected from deals
    mapping(address => uint256) public protocolProfitsTokens; //liquidated to paired at discount
    mapping(address => uint256) public protocolPairProfits;
    mapping(address => uint256) public protocolFeesTokens; //liquidated to paired at discount
    mapping(address => uint256) public protocolPairedFees;
    mapping(address => uint256) public hedgesCreatedVolume; //volume saved in paired currency
    mapping(address => uint256) public hedgesTakenVolume;
    mapping(address => uint256) public hedgesCostVolume;
    mapping(address => uint256) public swapsVolume;
    mapping(address => uint256) public optionsVolume;
    mapping(address => uint256) public settledVolume;

    // volume mappings
    mapping(address => uint256) public protocolCashierFees;
    mapping(address => mapping(address => uint256)) public equivUserHedged;
    mapping(address => mapping(address => uint256)) public equivUserCosts;

    // miner mappings
    mapping(address => bool) public minerMap;
}
