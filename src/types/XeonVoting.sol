// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

contract XeonVoting {
    //========== STATE VARIABLES ==========//
    uint8 public buyBackPercentage;
    mapping(address => uint256) public votes;
    uint256 public totalVotes;
    address[] public stakers;
    mapping(address => bool) public hasVoted;

    //========== EVENTS ==========//
    event BuybackPercentageUpdated(uint8 newPercentage);

    //========== MODIFIERS ==========//
    modifier onlyStaker() {
        require(votes[msg.sender] > 0, "Not a staker");
        _;
    }

    //========== FUNCTIONS ==========//

    /**
     * @notice Cast a vote for the buyback percentage.
     * @dev Only stakers can call this function, votes are weighted by the total amount staked.
     * @param percentage The percentage being voted for (1-100).
     */
    function voteForBuybackPercentage(uint256 stakedBalance, uint256 totalStaked, uint8 percentage) external {
        require(percentage >= 1 && percentage <= 100, "Invalid percentage");

        uint256 weightedVote = (percentage * stakedBalance) / totalStaked;

        // Remove the user's previous vote from the total votes
        if (hasVoted[msg.sender]) {
            totalVotes -= votes[msg.sender];
        } else {
            hasVoted[msg.sender] = true;
            stakers.push(msg.sender); // Add to stakers if this is their first vote
        }

        // Add the new vote to the total votes
        votes[msg.sender] = weightedVote;
        totalVotes += weightedVote;
    }

    /**
     * @notice Calculate and update the new buyback percentage.
     * @param totalStaked The total staked amount in the staking pool.
     * @return The new buyback percentage.
     */
    function calculateNewBuybackPercentage(uint256 totalStaked) external returns (uint8) {
        uint256 totalWeightedVotes;

        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            uint256 weightedVote;

            if (hasVoted[staker]) {
                weightedVote = votes[staker];
            } else {
                // Default vote value is the current buyBackPercentage + 10
                uint256 defaultVoteValue = buyBackPercentage + 10;
                if (defaultVoteValue > 100) {
                    defaultVoteValue = 100;
                }
                weightedVote = (defaultVoteValue * totalStaked) / totalStaked;
            }

            totalWeightedVotes += weightedVote;
        }

        // Calculate the new buyback percentage
        uint256 weightedAverage = totalWeightedVotes / totalStaked;
        buyBackPercentage = uint8((weightedAverage + buyBackPercentage) / 2);

        emit BuybackPercentageUpdated(buyBackPercentage);
        return buyBackPercentage;
    }

    /**
     * @notice Update the buyback percentage. This function should be called by the staking pool contract.
     * @param newPercentage The new buyback percentage to set.
     */
    function updateBuybackPercentage(uint8 newPercentage) external {
        require(newPercentage <= 100, "Invalid percentage");
        buyBackPercentage = newPercentage;

        emit BuybackPercentageUpdated(newPercentage);
    }

    /**
     * @dev Resets votes for the next epoch.
     */
    function resetVotes() external {
        for (uint256 i = 0; i < stakers.length; i++) {
            votes[stakers[i]] = 0;
            hasVoted[stakers[i]] = false;
        }
        totalVotes = 0;
    }
}
