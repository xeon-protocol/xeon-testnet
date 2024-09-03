// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

contract VotingContract {
    //========== STATE VARIABLES ==========//
    uint8 public buyBackPercentage;
    mapping(address => uint256) public votes;
    uint256 public totalVotes;
    address[] public stakers;

    //========== EVENTS ==========//
    event BuybackPercentageUpdated(uint8 newPercentage);

    //========== MODIFIERS ==========//
    modifier onlyStaker() {
        require(votes[msg.sender] > 0, "Not a staker");
        _;
    }

    //========== FUNCTIONS ==========//

    /**
     * @notice Cast a vote for the buyback percentage
     * @dev Only stakers can call this function, votes are weighted by the total amount staked.
     * @param percentage The percentage being voted for (1-100)
     */
    function voteForBuybackPercentage(uint256 stakedBalance, uint256 totalStaked, uint8 percentage)
        external
        onlyStaker
    {
        require(percentage >= 1 && percentage <= 100, "Invalid percentage");

        uint256 weightedVote = (percentage * stakedBalance) / totalStaked;

        // Remove the user's previous vote from the total votes
        if (votes[msg.sender] > 0) {
            totalVotes -= votes[msg.sender];
        }

        // Add the new vote to the total votes
        votes[msg.sender] = weightedVote;
        totalVotes += weightedVote;
    }

    /**
     * @dev Internal function to calculate the new buyback percentage
     * each staker's vote is proportional to the amount of XEON staked, relative
     * to the total amount staked. The previous buyback percentage is weighted
     * in to dampen percentage change between epochs.
     */
    function calculateNewBuybackPercentage(uint256 totalStaked) external returns (uint8) {
        uint256 totalWeightedVotes;

        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            uint256 stakedBalance = votes[staker];
            uint256 weightedVote = (stakedBalance * 100) / totalStaked;
            totalWeightedVotes += weightedVote;
        }

        // Calculate the new buyback percentage
        uint256 weightedAverage = totalWeightedVotes / totalStaked;
        buyBackPercentage = uint8((weightedAverage + buyBackPercentage) / 2);

        emit BuybackPercentageUpdated(buyBackPercentage);
        return buyBackPercentage;
    }

    /**
     * @dev Resets votes for the next epoch
     */
    function resetVotes() external {
        for (uint256 i = 0; i < stakers.length; i++) {
            votes[stakers[i]] = 0;
        }
        totalVotes = 0;
    }
}
