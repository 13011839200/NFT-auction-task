// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MetaNFT is ERC721 {
    address private _owner;
    

    constructor() ERC721("MetaNFT", "MFT") {
        _mint(msg.sender, 1);
        _owner = msg.sender;
    }

    function mint(address to, uint256 id) external onlyOwner {
        _safeMint(to, id);
    }

    function burn(uint256 id) external onlyOwner {
        require(msg.sender == ownerOf(id), "not owner");
        _burn(id);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "not owner");
        _;
    }
}
