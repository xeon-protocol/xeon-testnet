// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title XeonBookmarking Contract
 * @author Jon Bray <jon@xeon-protocol.io>
 * @dev this contract allows users to bookmark hedging options
 * it provides functions to toggle bookmarks, check bookmark status,
 * and retrieve all bookmarks for a user
 *
 * @notice this contract handles bookmarks for options across all chains
 * by using a unique composite key
 */
contract XeonBookmarking {
    //=============== MAPPINGS ===============//
    // mapping of bookmark status by [user][chainId][dealId]
    mapping(address => mapping(uint256 => mapping(uint256 => bool))) internal bookmarks;

    // mapping of bookmarked dealIds by [user][chainId]
    mapping(address => mapping(uint256 => uint256[])) internal bookmarkedOptions;

    // mapping of index of each bookmarked dealId in the bookmarkedOptions array
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) internal bookmarkIndex;

    //=============== EVENTS ===============//
    event BookmarkAdded(address indexed user, uint256 indexed chainId, uint256 indexed dealId);
    event BookmarkRemoved(address indexed user, uint256 indexed chainId, uint256 indexed dealId);

    //=============== FUNCTIONS ===============//
    /**
     * @notice adds a bookmark for a hedging option
     *
     * this function adds a bookmark for a hedging option based on its chainId and dealId
     * emits an event indicating the bookmark was added
     *
     * @param chainId ID of the chain
     * @param dealId unique identifier of the hedging option
     */
    function addBookmark(uint256 chainId, uint256 dealId) external {
        require(!bookmarks[msg.sender][chainId][dealId], "Bookmark already exists");

        // add the bookmark
        bookmarks[msg.sender][chainId][dealId] = true;
        bookmarkedOptions[msg.sender][chainId].push(dealId);
        bookmarkIndex[msg.sender][chainId][dealId] = bookmarkedOptions[msg.sender][chainId].length - 1;

        emit BookmarkAdded(msg.sender, chainId, dealId);
    }

    /**
     * @notice removes a bookmark for a hedging option
     *
     * this function removes a bookmark for a hedging option based on its chainId and dealId
     * emits an event indicating the bookmark was removed
     *
     * @param chainId ID of the chain
     * @param dealId unique identifier of the hedging option
     */
    function removeBookmark(uint256 chainId, uint256 dealId) external {
        require(bookmarks[msg.sender][chainId][dealId], "Bookmark does not exist");

        // get the index of the dealId to remove
        uint256 index = bookmarkIndex[msg.sender][chainId][dealId];
        uint256 lastIndex = bookmarkedOptions[msg.sender][chainId].length - 1;
        uint256 lastDealId = bookmarkedOptions[msg.sender][chainId][lastIndex];

        // swap the last dealId with the one to remove
        bookmarkedOptions[msg.sender][chainId][index] = lastDealId;
        bookmarkIndex[msg.sender][chainId][lastDealId] = index;

        // remove the last element
        bookmarkedOptions[msg.sender][chainId].pop();

        // cleanup the mappings
        delete bookmarks[msg.sender][chainId][dealId];
        delete bookmarkIndex[msg.sender][chainId][dealId];

        emit BookmarkRemoved(msg.sender, chainId, dealId);
    }

    /**
     * @notice gets the bookmark status of a hedging option for a specific user
     *
     * this function retrieves the bookmark status of a hedging option for a specific user
     *
     * @param user address of the user
     * @param chainId ID of the chain
     * @param dealId unique identifier of the hedging option
     * @return bookmark status
     */
    function getBookmark(address user, uint256 chainId, uint256 dealId) public view returns (bool) {
        return bookmarks[user][chainId][dealId];
    }

    /**
     * @notice gets all bookmarks of a user for a specific chain
     *
     * this function retrieves all bookmarks of a user for a specific chainId
     *
     * @param user address of the user
     * @param chainId ID of the chain
     * @return array containing all bookmarked hedging option IDs for the specified chain
     */
    function getUserBookmarks(address user, uint256 chainId) public view returns (uint256[] memory) {
        return bookmarkedOptions[user][chainId];
    }
}
