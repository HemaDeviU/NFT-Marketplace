// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SoulBoundToken is ERC721, Ownable {
    address marketplace;
    address soulBoundOwner;
    uint256 private tokenIdCounter;


    constructor() ERC721("SoulBoundToken", "SBT") Ownable(msg.sender){
        
    }
    function setMarketplace(address _marketplace) external onlyOwner {
        marketplace = _marketplace;
    }

    //seller mints token before adding listings
    function safeMint(address to) public onlyOwner {
        tokenIdCounter++;
        _safeMint(to, tokenIdCounter);
    }

    //seller burns token when leaving marketplace
    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender || marketplace == msg.sender, "Only the owner of the token or marketplace owner can burn it.");
        _burn(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256) pure override internal {
        require(from == address(0) || to == address(0), "This a Soulbound token. It cannot be transferred. It can only be burned by the token owner.");
    }

    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }
}


















