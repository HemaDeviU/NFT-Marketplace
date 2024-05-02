// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./SoulBoundToken.sol";


error NotSoulBoundSeller();
error PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error ItemNotForSale(address nftAddress, uint256 tokenId);
error NotListed(address nftAddress, uint256 tokenId);
error AlreadyListed(address nftAddress, uint256 tokenId);
error NoProceeds();
error NotOwner();
error NotApprovedForMarketplace();
error PriceMustBeAboveZero();
error ProceedsWithdrawn(address seller,uint256 amount);


contract NftMarketplace is ReentrancyGuard {
    address payable marketplaceOwner;
    address public soulboundAddress;

    constructor(address _soulboundAddress) IERC721("MarketplaceNFT", "NFTMP") {
        marketplaceOwner = payable(msg.sender);
        soulboundAddress = _soulboundAddress;
    }
    mapping(address => mapping(uint256 => Listing)) private s_listings;
    mapping(address => uint256) private s_proceeds;


    struct Listing {
        uint256 price;
        address seller;
    }

    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemCanceled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

   

    modifier notListed(address nftAddress,uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price > 0) {
            revert AlreadyListed(nftAddress, tokenId);
        }
        _;
    }

    modifier isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price <= 0) {
            revert NotListed(nftAddress, tokenId);
        }
        _;
    }

    modifier isSeller(address nftAddress,uint256 tokenId,address spender) {
        SoulBoundToken soulBound = SoulBoundToken(soulboundAddress);
        if(!soulBound.ownerOf(tokenId)==spender){
            revert NotSoulBoundSeller();
        }
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NotOwner();
        }
        _;
    }

    function listItem(address nftAddress, uint256 tokenId, uint256 price)external notListed(nftAddress, tokenId) isSeller(nftAddress, tokenId, msg.sender)
    {
        if (price <= 0) {
            revert PriceMustBeAboveZero();
        }
        IERC721 nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this)) {
            revert NotApprovedForMarketplace();
        }
        s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
        emit ItemListed(msg.sender, nftAddress, tokenId, price);
    }

  
    function cancelListing(address nftAddress, uint256 tokenId)external isSeller(nftAddress, tokenId, msg.sender) isListed(nftAddress, tokenId)
    {
        emit ItemCanceled(msg.sender, nftAddress, tokenId);
        delete (s_listings[nftAddress][tokenId]);
        if(s_listings[msg.sender] = 0)
        {
             _burnSoulBoundToken(msg.sender);
        }
        
    }


    function buyItem(address nftAddress, uint256 tokenId)external payable isListed(nftAddress, tokenId) nonReentrant
    {
        Listing memory listedItem = s_listings[nftAddress][tokenId];
        if (msg.value < listedItem.price) {
            revert PriceNotMet(nftAddress, tokenId, listedItem.price);
        }
        emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
        s_proceeds[listedItem.seller] += msg.value;
        delete (s_listings[nftAddress][tokenId]);
        if(s_listings[listedItem.seller] = 0)
        {
             _burnSoulBoundToken(msg.sender);
        }
        IERC721(nftAddress).safeTransferFrom(listedItem.seller, msg.sender, tokenId);
        
    }

    function updateListing(address nftAddress,uint256 tokenId,uint256 newPrice) external isListed(nftAddress, tokenId) nonReentrant isSeller(nftAddress, tokenId, msg.sender)
    {
        if (newPrice <= 0) {
            revert PriceMustBeAboveZero();
        }
        s_listings[nftAddress][tokenId].price = newPrice;
        emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
    }

   
    function withdrawProceeds() external nonReentrant{
         uint256 proceeds = s_proceeds[msg.sender];
        if (proceeds <= 0) {
            revert NoProceeds();
        }
        emit ProceedsWithdrawn(msg.sender, proceeds);
        s_proceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        require(success, "Transfer failed");
    }



    function _burnSoulBoundToken() internal {    
        SoulBoundToken(soulboundAddress).burn(msg.sender); // Burn the seller's token
    }

    function getListing(address nftAddress, uint256 tokenId) external view returns (Listing memory)
    {
        return s_listings[nftAddress][tokenId];
    }

    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }
}