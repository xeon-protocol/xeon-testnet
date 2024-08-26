// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract XeonTokenDistributor is Ownable {
    /* ============ State Variables ============ */
    IERC20 public xeonToken;
    uint256 public constant CLAIM_AMOUNT = 10_000 * 10 ** 18;
    mapping(address => bool) public hasClaimed;

    /* ============ Events ============ */
    event XeonClaimed(address indexed user, uint256 amount);
    event InsufficientBalance(address indexed user, uint256 requestedAmount, uint256 availableAmount);

    /* ============ Constructor ============ */
    constructor(IERC20 _xeonToken) Ownable(msg.sender) {
        xeonToken = _xeonToken;
    }

    /* ============ External Functions ============ */
    /**
     * @dev Claim 10,000 XEON tokens. Can only be claimed once.
     */
    function claimXeon() external {
        require(!hasClaimed[msg.sender], "XeonTokenDistributor: Already claimed");

        uint256 contractBalance = xeonToken.balanceOf(address(this));
        if (contractBalance < CLAIM_AMOUNT) {
            emit InsufficientBalance(msg.sender, CLAIM_AMOUNT, contractBalance);
            revert("XeonTokenDistributor: Insufficient balance in contract");
        }

        hasClaimed[msg.sender] = true;
        xeonToken.transfer(msg.sender, CLAIM_AMOUNT);

        emit XeonClaimed(msg.sender, CLAIM_AMOUNT);
    }

    /* ============ External View Functions ============ */
    /**
     * @dev Check if a user has already claimed XEON tokens.
     * @param user The address of the user.
     * @return True if the user has already claimed, false otherwise.
     */
    function hasUserClaimed(address user) external view returns (bool) {
        return hasClaimed[user];
    }

    /**
     * @dev Retrieve the current XEON token balance of the contract.
     * @return The balance of XEON tokens held by the contract.
     */
    function getContractBalance() external view returns (uint256) {
        return xeonToken.balanceOf(address(this));
    }
}
