// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

contract XeonBookmarking {
    //=============== MAPPINGS ===============//
    mapping(address => mapping(uint256 => bool)) public bookmarks;
    mapping(address => uint256[]) public bookmarkedOptions;

    //=============== EVENTS ===============//
    event BookmarkToggle(address indexed user, uint256 hedgeId, bool bookmarked);

    //=============== FUNCTIONS ===============//
    /**
     * @notice Toggles the bookmark status of a hedging option using its ID.
     *
     * This function toggles the bookmark status of a hedging option based on its ID for the caller.
     * It emits an event indicating the toggle action.
     *
     * @param _dealID The unique identifier of the hedging option.
     */
    function bookmarkHedge(uint256 _dealID) external {
        bool bookmarked = bookmarks[msg.sender][_dealID];
        bookmarks[msg.sender][_dealID] = !bookmarked;
        emit BookmarkToggle(msg.sender, _dealID, !bookmarked);
        // Update bookmarkedOptions array for wallet
        if (!bookmarked) {
            bookmarkedOptions[msg.sender].push(_dealID);
        } else {
            uint256[] storage options = bookmarkedOptions[msg.sender];
            for (uint256 i = 0; i < options.length; i++) {
                if (options[i] == _dealID) {
                    // When values match, remove the dealId from array
                    if (i < options.length - 1) {
                        options[i] = options[options.length - 1];
                    }
                    options.pop();
                    break;
                }
            }
        }
    }

    /**
     * @notice Gets the bookmark status of a hedging option for a specific user.
     *
     * This function retrieves the bookmark status of a hedging option for a specific user.
     *
     * @param user The address of the user.
     * @param _dealID The unique identifier of the hedging option.
     * @return The bookmark status.
     */
    function getBookmark(address user, uint256 _dealID) public view returns (bool) {
        return bookmarks[user][_dealID];
    }

    /**
     * @notice Gets all bookmarks of a user.
     *
     * This function retrieves all bookmarks of a user.
     *
     * @param user The address of the user.
     * @return An array containing all bookmarked hedging option IDs.
     */
    function getUserBookmarks(address user) public view returns (uint256[] memory) {
        return bookmarkedOptions[user];
    }
}
