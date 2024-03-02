// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/ERC6551Registry.sol";
import "../src/ProjectAccount.sol";
import "../src/Rentals.sol";
import "../src/BlockEstate.sol";
import "../src/MockERC20.sol";
import "../src/BeaconERC20.sol";



contract BlockEstateTest is Test {

    ERC6551Registry public registry;
    Rentals public rentalsImplementation;
    BeaconERC20 public beacon;
    ProjectAccount public projectAccountImplementation;
    BlockEstate public blockEstate;
    MockERC20 public paymentToken;

    address owner = vm.addr(1);

    

    function setUp() public {
        console.log("owner", owner);
        vm.prank(owner);
        rentalsImplementation = new Rentals();
        vm.prank(owner);
        registry = new ERC6551Registry(); 

        vm.prank(owner);
        beacon = new BeaconERC20(address(rentalsImplementation)); //rentals
        vm.prank(owner);
        projectAccountImplementation = new ProjectAccount();

        vm.prank(owner);
        paymentToken = new MockERC20("USD TEST", "TEST");
        vm.prank(owner);
        blockEstate = new BlockEstate(address(registry), address(projectAccountImplementation), 
                address(paymentToken), address(beacon));


    }

    function testMintProject() public {
        string memory symbol = "TEST";
        
        uint256 pricePerDay = 100 ether;
        uint256 totalSupply = 20 ether;
        uint256 totalAmountToRaise = 500000 ether;
        uint256 deadline = block.timestamp + 30 days;
        vm.prank(owner);
        uint256 tokenId = blockEstate.mintProject("Test", symbol, pricePerDay, totalSupply, totalAmountToRaise, deadline);
        
        assertTrue(tokenId >= 0);

        assertTrue(blockEstate.ownerOf(tokenId) == address(blockEstate));

        address predictedProjectAccount = registry.account(
            address(blockEstate.erc6551Implementation()),
            block.chainid,
            address(blockEstate),
            tokenId,
            0
        );

        assertEq(blockEstate.projectsAccounts(tokenId), predictedProjectAccount);
        
    }
}