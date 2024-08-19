// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Xeon Price Oracle (Testnet)
 * @author Jon Bray <jon@xeon-protocol.io>
 * @notice this is a testnet price oracle that allows for manual price changes
 */
contract PriceOracle is Ownable {
    //=============== STATE VARIABLES ===============//
    address public constant oVELA = 0xb7E16D46f26B1615Dcc501931F28F07fD4b0D7F4;
    address public constant oPEPE = 0x7dC9ecE25dcCA41D8a627cb47ded4a9322f7722b;
    address public constant oDEGEN = 0x9B9852A943a570685c3704d70C4F1ebD5EdE109B;
    address public constant oHIGHER = 0x9855d38b7E6270B9f22F283A0C62330b16Ac909C;
    address public constant oROR = 0xEb2DCAFFFf1b0d5BA76F14Fe6bB8348126339FcB;
    address public constant WETH = 0x395cB7753B02A15ed1C099DFc36bF00171F18218;

    //=============== MAPPINGS ===============//
    mapping(address => uint256) private tokenPrices;

    //=============== EVENTS ===============//
    event PriceUpdated(address indexed token, uint256 price);

    //=============== CONSTRUCTOR ===============//
    constructor() Ownable(msg.sender) {
        tokenPrices[oVELA] = 0;
        tokenPrices[oPEPE] = 0;
        tokenPrices[oDEGEN] = 0;
        tokenPrices[oHIGHER] = 0;
        tokenPrices[oROR] = 0;
    }

    //=============== EXTERNAL FUNCTIONS ===============//
    /**
     * @notice Sets the price of a token in WETH
     * @param token The address of the token
     * @param priceInWETH The price of the token in WETH
     */
    function setTokenPriceInWETH(address token, uint256 priceInWETH) external onlyOwner {
        tokenPrices[token] = priceInWETH;
        emit PriceUpdated(token, priceInWETH);
    }

    /**
     * @notice Sets the price of WETH in USD
     * @param priceInUSD The price of WETH in USD
     */
    function setWETHPriceInUSD(uint256 priceInUSD) external onlyOwner {
        tokenPrices[WETH] = priceInUSD;
        emit PriceUpdated(WETH, priceInUSD);
    }

    //=============== GETTERS ===============//
    function getValueInWETH(address token) external view returns (uint256) {
        return tokenPrices[token];
    }
}
