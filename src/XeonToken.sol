// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Xeon Token (Testnet)
 * @author [Jon Bray](https://warpcast.com/jonbray.eth)
 * @notice 100m supply
 * @notice this is the testnet version of XeonToken for staking and does not include buy/sell tax
 */
contract XeonToken is ERC20, Ownable {
    //=============== STATE VARIABLES ===============//
    string public constant TOKEN_NAME = "Xeon Protocol";
    string public constant TOKEN_SYMBOL = "XEON";
    uint256 public constant TOKEN_INITIAL_SUPPLY = 100_000_000;

    //=============== CONSTRUCTOR ===============//
    constructor() ERC20(TOKEN_NAME, TOKEN_SYMBOL) Ownable(msg.sender) {
        _mint(msg.sender, TOKEN_INITIAL_SUPPLY * 10 ** decimals());
    }

    /**
     * @dev recover tokens sent to the contract address
     * @param token the address of the token to recover
     * @param amount the amount of tokens to recover
     * @param to the address to send the recovered tokens to
     */
    function recoverTokens(address token, uint256 amount, address to) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }
    // the following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value) internal override(ERC20) {
        super._update(from, to, value);
    }
}
