// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "@upgradeable/contracts/access/OwnableUpgradeable.sol";

import "./BlockEstate.sol";
import "./ProjectAccount.sol";


contract Rentals is ERC721Upgradeable, OwnableUpgradeable {

    uint256 internal INITIAL_CHAIN_ID;
    bytes32 internal INITIAL_DOMAIN_SEPARATOR;

    IERC20 public paymentToken;
    BlockEstate public blockEstate;
    ProjectAccount projectAccount;

    uint256 public rentalsCounter;
    uint256 public rentalPriceperDay;

    bool public availableToRent;

    //Rentals logic
    mapping(uint256 => uint256) public startDates;
    mapping(uint256 => uint256) public endDates;
    mapping(uint256 => bool) public rentalStarted;

    mapping(address => mapping(uint256 => uint256)) public amountsLockedForRentals; 
    
    mapping(uint256 => bool) public availableDays;

    //EVENTS

    event RentalMinted(uint256 indexed _tokenId, address indexed _account, uint256 indexed _startDate, uint256 _endDate);
    event RentalSplit(uint256 indexed _tokenId, address indexed _account, uint256[] _intermediaryDates);
    

    //MODIFIERS
    modifier onlyManager() {
        require(_msgSender() == address(blockEstate), "Rentals: caller is not the BlockEstate");
        _;
    }

    modifier OnlyProjectAccount() {
        require(_msgSender() == address(projectAccount), "Rentals: caller is not the project account");
        _;
    }

    constructor(){
        _disableInitializers();
    }

    function initialize(string calldata _name, string calldata _symbol, 
     address _paymentToken, address blockEstateAddress, uint256 _rentalPriceperDay, address _projectAccount)
    initializer public {

        paymentToken = IERC20(_paymentToken);
        blockEstate = BlockEstate(blockEstateAddress);
        rentalPriceperDay = _rentalPriceperDay;
        projectAccount = ProjectAccount(payable(_projectAccount));
        
        __ERC721_init(_name,_symbol);
        transferOwnership(_msgSender());
        
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }



    function rentProperty(address _to, uint256 _startDate, uint256 _endDate) public returns (uint256) {
        require(_startDate < _endDate, "Rentals: start date must be before end date");
        require(_startDate > block.timestamp, "Rentals: start date must be in the future");
        require(availableToRent, "Rentals: property is not available to rent");
        for(uint256 i = _startDate; i <= _endDate; i += 1){
            if(!availableDays[i]) {
                revert("Rentals: date already rented");
            }
            availableDays[i] = false;
        }

        uint256 tokenId = rentalsCounter;
        rentalsCounter++;

        startDates[tokenId] = _startDate;
        endDates[tokenId] = _endDate;

        uint256 amountToMakeDiscount = projectAccount.erc721BalanceOf(msg.sender);

        uint256 discountInBps = amountToMakeDiscount * 10000 / projectAccount.totalSupply();

        projectAccount.erc721TransferFrom(msg.sender, address(this), amountToMakeDiscount);
        
        amountsLockedForRentals[msg.sender][tokenId] = amountToMakeDiscount;

        uint256 price = rentalPriceperDay * (_endDate - _startDate) * discountInBps / 10000;

        bool success = IERC20(paymentToken).transfer(address(projectAccount), price);
        if (!success) {
            revert("Rentals: payment failed");
        }
        _mint(_to, tokenId);
        emit RentalMinted(tokenId, _to, _startDate, _endDate);

        return tokenId;
    }

    function retrieveAmountLocked(uint256 _tokenId) public {
        require(endDates[_tokenId] < block.timestamp, "Rentals: rental has not ended yet");

        uint256 amount = amountsLockedForRentals[_msgSender()][_tokenId];

        amountsLockedForRentals[_msgSender()][_tokenId] = 0;
        projectAccount.erc721TransferFrom(address(this), _msgSender(), amount);
        
    }

    function setPricePerDay(uint256 _newPrice) public OnlyProjectAccount() {
        rentalPriceperDay = _newPrice;
    }

    function setPaymentToken(address _newPaymentToken) public OnlyProjectAccount() {
        paymentToken = IERC20(_newPaymentToken);
    }

    function splitRental(uint256 _tokenId, uint256[] calldata _intermediaryDates) public {
        require(ownerOf(_tokenId) == _msgSender(), "Rentals: caller is not the owner of the rental");
        require(startDates[_tokenId] > block.timestamp, "Rentals: rental has already started");
        require(_intermediaryDates.length > 0, "Rentals: no intermediary dates provided");
        require(!rentalStarted[_tokenId], "Rentals: rental has already started");

        _burn(_tokenId);

        for(uint256 i = startDates[_tokenId]; i < endDates[_tokenId]; i += 1){
            availableDays[i] = true;
        }

        uint256 previousDate = startDates[_tokenId];
        for(uint256 i = 0; i < _intermediaryDates.length; i++){
            require(_intermediaryDates[i] > previousDate, "Rentals: intermediary dates must be in ascending order");
            require(_intermediaryDates[i] < endDates[_tokenId], "Rentals: intermediary dates must be before the end date");
            rentProperty(_msgSender(), previousDate, _intermediaryDates[i]);
            previousDate = _intermediaryDates[i];
        }
        uint256 amountLocked = amountsLockedForRentals[_msgSender()][_tokenId];
        amountsLockedForRentals[_msgSender()][_tokenId] = 0;

        uint256 lastTokenId = rentProperty(_msgSender(), previousDate, endDates[_tokenId]);
        amountsLockedForRentals[_msgSender()][lastTokenId] = amountLocked;
        
        emit RentalSplit(_tokenId, _msgSender(), _intermediaryDates);
        
    }

    function setAvailableToRent() public onlyManager() {
        availableToRent = true;
    }

    function setUnavailableToRent() public onlyManager() {
        availableToRent = false;
    }

    

    

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name())),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }
}