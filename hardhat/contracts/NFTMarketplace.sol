// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTMarketplace {
    struct Listing {
        uint256 price;
        address seller;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;

    // modifier to check if nftAddress is not a valid address(address zero)
    modifier checkIfAddressZero(address nftAddress) {
        require(
            nftAddress != address(0),
            "Address zero is not a valid address"
        );
        _;
    }

    // modifier to check if _price is at least one wei
    modifier checkIfValidPrice(uint256 _price) {
        require(_price > 0, "MRKT: Price must be > 0");
        _;
    }
    // modifier to check if caller is the owner of the NFT with tokenId
    modifier isNFTOwner(address nftAddress, uint256 tokenId) {
        require(
            IERC721(nftAddress).ownerOf(tokenId) == msg.sender,
            "MRKT: Not the owner"
        );
        _;
    }
    // modifier to check if NFT is not listed on the platform
    modifier isNotListed(address nftAddress, uint256 tokenId) {
        require(
            listings[nftAddress][tokenId].price == 0,
            "MRKT: Already listed"
        );
        _;
    }
    // modifier to check if NFT is already listed on the platform
    modifier isListed(address nftAddress, uint256 tokenId) {
        require(listings[nftAddress][tokenId].price > 0, "MRKT: Not listed");
        _;
    }

    event ListingCreated(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        address seller
    );

    event ListingCanceled(address nftAddress, uint256 tokenId, address seller);

    event ListingUpdated(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice,
        address seller
    );

    event ListingPurchased(
        address nftAddress,
        uint256 tokenId,
        address seller,
        address buyer
    );

    /**
     * @dev allow users to create a listing with an NFT they own
     * @param nftAddress the address of the smartcontract's the NFT originates from
     * @param tokenId the id of the NFT
     * @param price the price to sell the NFT for
     */
    function createListing(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    )
        external
        checkIfAddressZero(nftAddress)
        checkIfValidPrice(price)
        isNotListed(nftAddress, tokenId)
        isNFTOwner(nftAddress, tokenId)
    {
        IERC721 nftContract = IERC721(nftAddress);
        require(
            nftContract.getApproved(tokenId) == address(this),
            "MRKT: No approval for NFT"
        );
        listings[nftAddress][tokenId] = Listing({
            price: price,
            seller: msg.sender
        });

        emit ListingCreated(nftAddress, tokenId, price, msg.sender);
    }

    /**
        * @dev allow sellers to cancel their listings
        * @param nftAddress the address of the smartcontract's the NFT originates from
        * @param tokenId the id of the NFT

     */
    function cancelListing(address nftAddress, uint256 tokenId)
        external
        checkIfAddressZero(nftAddress)
        isListed(nftAddress, tokenId)
        isNFTOwner(nftAddress, tokenId)
    {
        delete listings[nftAddress][tokenId];
        emit ListingCanceled(nftAddress, tokenId, msg.sender);
    }

    /**
        * @dev allow sellers to update the price of their listings
        * @param nftAddress the address of the smartcontract's the NFT originates from
        * @param tokenId the id of the NFT
        * @param newPrice the new selling price for NFT

     */
    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice
    )
        external
        checkIfAddressZero(nftAddress)
        checkIfValidPrice(newPrice)
        isListed(nftAddress, tokenId)
        isNFTOwner(nftAddress, tokenId)
    {
        listings[nftAddress][tokenId].price = newPrice;
        emit ListingUpdated(nftAddress, tokenId, newPrice, msg.sender);
    }

    /**
        * @dev allow users to purchase the NFTs listed
        * @param nftAddress the address of the smartcontract's the NFT originates from
        * @param tokenId the id of the NFT

     */
    function purchaseListing(address nftAddress, uint256 tokenId)
        external
        payable
        checkIfAddressZero(nftAddress)
        isListed(nftAddress, tokenId)
    {
        Listing memory listing = listings[nftAddress][tokenId];
        require(msg.value == listing.price, "MRKT: Incorrect ETH supplied");

        delete listings[nftAddress][tokenId];

        IERC721(nftAddress).safeTransferFrom(
            listing.seller,
            msg.sender,
            tokenId
        );
        (bool success, ) = payable(listing.seller).call{value: msg.value}("");
        require(success, "Transfer of payment to seller failed");

        emit ListingPurchased(nftAddress, tokenId, listing.seller, msg.sender);
    }
}
