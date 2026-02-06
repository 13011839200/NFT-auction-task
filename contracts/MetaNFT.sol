// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-4.7.3/utils/Counters.sol";

using Counters for Counters.Counter;


contract MetaNFT is ERC721 {

    Counters.Counter private _tokenIdCounter;

    address private _owner;

    

    constructor() ERC721("MetaNFT", "MFT") {
        uint256 tokenId = _tokenIdCounter.current();
        _mint(msg.sender, tokenId);
        _tokenIdCounter.increment();
        _owner = msg.sender;
    }

    function mint(address to) external onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(to, tokenId);
        _tokenIdCounter.increment();
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
