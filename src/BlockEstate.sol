// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import "./interface/IERC6551Registry.sol";
import "./Rentals.sol";


contract BlockEstate is ERC721, Ownable {

    //GLOBAL VARIABLES
    uint256 public projectsCounter;
    address public erc6551Implementation;
    IERC6551Registry public erc6551Registry;
    IERC20 paymentToken;
    address proxyImplementation;

    //EVENTS

    event ProjectMinted(uint256 indexed _tokenId, address indexed _account, address indexed _rentalsCollection);

    //MAPPINGS TO NFTs

    mapping(uint256 => address) public projectsAccounts;
    mapping(uint256 => address) public projectsRentalsCollections;


    constructor(address _erc6551Registry, address _erc6551Implementation, 
                    address _paymentToken, address _proxyImplementation) 
        Ownable(_msgSender()) ERC721("BlockEstate", "BLOCKX"){

        erc6551Registry =  IERC6551Registry(_erc6551Registry);
        erc6551Implementation = _erc6551Implementation;
        paymentToken = IERC20(_paymentToken);
        proxyImplementation = _proxyImplementation;

    }

    function mintProject(string calldata _name, string calldata _symbol, uint256 _rentalPriceperDay) public onlyOwner() returns (uint256){
        uint256 tokenId = projectsCounter;

        projectsCounter++;

        _mint(address(this), tokenId);

        address projectAccount = erc6551Registry.createAccount(
            address(erc6551Implementation),
            block.chainid,
            address(this),
            tokenId,
            0,
            ""
        );
        projectsAccounts[tokenId] = projectAccount;

        BeaconProxy rentalCollection = new BeaconProxy(proxyImplementation,
            abi.encodeWithSelector(Rentals(address(0)).initialize.selector, 
            _name, _symbol, address(paymentToken), address(this), _rentalPriceperDay, projectAccount));

        projectsRentalsCollections[tokenId] = address(rentalCollection);

        emit ProjectMinted(tokenId, projectAccount, address(rentalCollection));
        return tokenId;
    }

}