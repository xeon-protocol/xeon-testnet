// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract XeonFeeManagement is Ownable(msg.sender), ReentrancyGuard {
    //=============== STATE VARIABLES ===============//
    uint256 public feeNumerator;
    uint256 public feeDenominator;
    uint256 public protocolFeeRate;
    uint256 public validatorFeeRate;

    //=============== EVENTS ===============//
    event ValidatorFeeUpdated(uint256 protocolFeeRate, uint256 validatorFeeRate);
    event FeeUpdated(uint256 feeNumerator, uint256 feeDenominator);

    //=============== FUNCTIONS ===============//
    /**
     * @notice Calculates the fee based on the given amount.
     *
     * This function calculates the fee based on the given amount and the fee numerator and denominator.
     *
     * @param amount The amount for which the fee is calculated.
     * @return The calculated fee amount.
     */
    function calculateFee(uint256 amount) public view returns (uint256) {
        require(amount >= feeDenominator, "Revenue is too small");
        uint256 amountInLarge = amount * (feeDenominator - feeNumerator);
        uint256 amountIn = amountInLarge / feeDenominator;
        uint256 fee = amount - amountIn;
        return fee;
    }

    /**
     * @notice Updates the protocol fee.
     *
     * This function updates the numerator and denominator of the protocol fee.
     *
     * @param numerator The new numerator of the fee.
     * @param denominator The new denominator of the fee.
     */
    function updateFee(uint256 numerator, uint256 denominator) external onlyOwner {
        feeNumerator = numerator;
        feeDenominator = denominator;
        emit FeeUpdated(numerator, denominator);
    }

    /**
     * @notice Updates the validator fee.
     *
     * This function updates the validator fee as a pecentage
     *
     * @param protocolPercent The percentage amount of protocol fee.
     * @param validatorPercent The percentage amount of validator fee.
     */
    function updateValidatorFee(uint256 protocolPercent, uint256 validatorPercent) external onlyOwner {
        // check that protocolFeeRate + validatorFeeRate == 100
        require(protocolPercent + validatorPercent == 100, "Total fee rate must be 100");
        protocolFeeRate = protocolPercent;
        validatorFeeRate = validatorPercent;
        emit ValidatorFeeUpdated(protocolFeeRate, validatorFeeRate);
    }
}
