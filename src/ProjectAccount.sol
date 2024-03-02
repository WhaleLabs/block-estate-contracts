// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@upgradeable/contracts/proxy/utils/Initializable.sol";

import "./lib/ERC404.sol";
import "./interface/IERC6551Account.sol";

import "forge-std/console.sol";



contract ProjectAccount is IERC165, IERC1271, IERC6551Account, ERC404, Initializable {

    //IMPORTANT: The implementation used for ERC404 doesn't have the constructor function. Instead, we are using the initializer function from the Initializable contract.
    
    receive() external payable {}

    IERC20 public paymentToken;
    address public manager;
    uint256 public totalAmountToRaise;
    uint256 public deadline;

    bool public successfulSale = false;
    bool public raisingFunds = true;

    modifier onlyManager() {
        require(msg.sender == manager, "Not manager");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    
    function initialize(uint256 _totalSupply, address _manager) initializer public {
        decimals = 18;
        units = 10 ** decimals;

        // EIP-2612 initialization
        _INITIAL_CHAIN_ID = block.chainid;
        _INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
        manager = _manager;

        _mintERC20(address(this), _totalSupply);
    }

    function setPaymentToken(address _paymentToken) public onlyManager {
        paymentToken = IERC20(_paymentToken);
    }
    function setTotalAmountToRaise(uint256 _totalAmountToRaise) public onlyManager {
        totalAmountToRaise = _totalAmountToRaise;
    }

    function setDeadline(uint256 _deadline) public onlyManager {
        deadline = _deadline;
    }

    function setName(string memory _name) public onlyManager {
        name = _name;
        symbol = _name;
    }

    function engage(address _to, uint256 _amount) public {
        require(_amount <= totalAmountToRaise, "Not enough funds");
        require(block.timestamp < deadline, "Deadline reached");

        uint256 price = (_amount/totalSupply) * totalAmountToRaise;
        paymentToken.transfer(address(this), price);

        _transferERC20(address(this), _to, _amount);
    }

    function managerWithdraw(address _to, uint256 _amount) public onlyManager {
        require(block.timestamp > deadline, "Deadline not reached");
        require(successfulSale, "Sale was not successful");

        paymentToken.transferFrom(address(this), _to, _amount);
    }

    function setFailedSale() public onlyManager {
        successfulSale = false;
    }

    function setSuccessfulSale() public onlyManager {
        successfulSale = true;
    }

    function retriveTokensAfterFailedSale(uint256 _amount) public {
        require(block.timestamp > deadline, "Deadline not reached");
        require(!successfulSale, "Sale was successful");
        require(!raisingFunds, "Raising funds is active");
        require(erc20BalanceOf(address(this)) >= _amount, "Not enough funds");

        _transferERC20(msg.sender, address(this), _amount);

        uint256 price = (_amount/totalSupply) * totalAmountToRaise;
        paymentToken.transferFrom(address(this), msg.sender, price);

    }

    function stopRaisingFunds() public onlyManager {
        raisingFunds = false;
    }

    function startRaisingFunds() public onlyManager {
        raisingFunds = true;
    }


    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) { //TODO

        string memory baseURI = "";
        return bytes(baseURI).length > 0 ? string.concat(baseURI, Strings.toString(_tokenId)) : "";
    }


    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view returns (bytes4 magicValue) {
        bool isValid = SignatureChecker.isValidSignatureNow(
            owner(),
            hash,
            signature
        );

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return "";
    }

    function token() public view returns (uint256, address, uint256) {
        bytes memory footer = new bytes(0x60);

        assembly {
            extcodecopy(address(), add(footer, 0x20), 0x4d, 0x60)
        }

        return abi.decode(footer, (uint256, address, uint256));
    }

    function owner() public view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = token();
        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    function _isValidSigner(address signer) internal view returns (bool) {
        return signer == owner();
    }

    function supportsInterface(
    bytes4 interfaceId
  ) public view virtual returns (bool) {
    return
      interfaceId == type(IERC404).interfaceId ||
      interfaceId == type(IERC165).interfaceId;
  }

    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable override returns (bytes memory) {}

    function nonce() external view override returns (uint256) {}

}