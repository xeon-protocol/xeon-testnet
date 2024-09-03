import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract XeonHedgePositions is ERC721 {
    /* todo: ensure we skip 0 */
    uint256 public nextTokenId = 1;

    constructor() ERC721("Xeon Hedge Position V1", "XEON-V1-POS") {}

    function mintHedgePosition(address to) internal returns (uint256) {
        uint256 tokenId = nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }
}
