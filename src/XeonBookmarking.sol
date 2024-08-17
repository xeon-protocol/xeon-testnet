// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title XeonBookmarking Contract
 * @author Jon Bray <jon@xeon-protocol.io>
 * @dev this contract allows users to bookmark hedging options
 * it provides functions to toggle bookmarks, check bookmark status,
 * and retrieve all bookmarks for a user
 */
contract XeonBookmarking {
    //=============== MAPPINGS ===============//
    // mapping of bookmark status by user and dealId
    mapping(address => mapping(uint256 => bool)) internal bookmarks;
    // mapping of bookmark index by user and dealId
    mapping(address => mapping(uint256 => uint256)) internal bookmarkIndex;
    // mapping of bookmarks for a user by dealId
    mapping(address => uint256[]) internal bookmarkedOptions;

    //=============== EVENTS ===============//
    event BookmarkAdded(address indexed user, uint256 hedgeId);
    event BookmarkRemoved(address indexed user, uint256 hedgeId);

    //=============== FUNCTIONS ===============//

    /**
     * @notice add bookmark for a hedging option using dealId
     *
     * this function adds a bookmark for a hedging option based on its dealId for the caller
     * emits an event indicating the bookmark was added
     *
     * @param _dealId unique identifier of the hedging option
     */
    function addBookmark(uint256 _dealId) external {
        require(!bookmarks[msg.sender][_dealId], "Bookmark already exists");

        // Add the bookmark
        bookmarkedOptions[msg.sender].push(_dealId);
        bookmarks[msg.sender][_dealId] = true;
        bookmarkIndex[msg.sender][_dealId] = bookmarkedOptions[msg.sender].length - 1;

        emit BookmarkAdded(msg.sender, _dealId);
    }

    /**
     * @notice removes a bookmark for a hedging option using its ID
     *
     * this function removes a bookmark for a hedging option based on its dealId for the caller
     * emits an event indicating the bookmark was removed
     *
     * @param _dealId unique identifier of the hedging option
     */
    function removeBookmark(uint256 _dealId) external {
        require(bookmarks[msg.sender][_dealId], "Bookmark does not exist");

        // Remove the bookmark
        uint256 index = bookmarkIndex[msg.sender][_dealId];
        uint256 lastIndex = bookmarkedOptions[msg.sender].length - 1;
        uint256 lastDealId = bookmarkedOptions[msg.sender][lastIndex];

        // Swap and pop
        bookmarkedOptions[msg.sender][index] = lastDealId;
        bookmarkIndex[msg.sender][lastDealId] = index;

        bookmarkedOptions[msg.sender].pop();
        delete bookmarks[msg.sender][_dealId];
        delete bookmarkIndex[msg.sender][_dealId];

        emit BookmarkRemoved(msg.sender, _dealId);
    }

    /**
     * @notice get the bookmark status of a hedging option for a specific user.
     *
     * @param user address of the user
     * @param _dealId unique identifier of the hedging option
     * @return bookmark status
     */
    function getBookmark(address user, uint256 _dealId) public view returns (bool) {
        return bookmarks[user][_dealId];
    }

    /**
     * @notice get all bookmarks of a user
     *
     * @param user address of the user.
     * @return array containing all bookmarked hedging option IDs
     */
    function getUserBookmarks(address user) public view returns (uint256[] memory) {
        return bookmarkedOptions[user];
    }
}
