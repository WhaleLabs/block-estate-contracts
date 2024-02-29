// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@upgradeable/contracts/proxy/utils/Initializable.sol";

import "./lib/ERC404.sol";
import "./interface/IERC6551Account.sol";



contract ProjectAccount is IERC165, IERC1271, IERC6551Account, ERC404, Initializable {

    //IMPORTANT: The implementation used for ERC404 doesn't have the constructor function. Instead, we are using the initializer function from the Initializable contract.
    
    receive() external payable {}

    constructor() {
        _disableInitializers();
    }

    
    function initialize(string memory name_, string memory symbol_, uint8 decimals_) initializer public {
        name = name_;
        symbol = symbol_;

        if (decimals_ < 18) {
        revert DecimalsTooLow();
        }

        decimals = decimals_;
        units = 10 ** decimals;

        // EIP-2612 initialization
        _INITIAL_CHAIN_ID = block.chainid;
        _INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
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