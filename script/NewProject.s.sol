// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/ERC6551Registry.sol";
import "../src/ProjectAccount.sol";
import "../src/Rentals.sol";
import "../src/BlockEstate.sol";
import "../src/MockERC20.sol";
import "../src/BeaconERC20.sol";

contract NewProject is Script {
    ERC6551Registry public registry;
    
    BlockEstate public blockEstate;
    

    function setUp() public {}

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        blockEstate = BlockEstate(0x82D58B15A6aDa9BbaAaD253CdfC5c97b5890811F);

        uint256 tokenId = blockEstate.mintProject("PROJECT1", "PRJ1", 100 ether, 20 ether, 500000 ether, block.timestamp + 30 days);

        address projectAccount = blockEstate.projectsAccounts(tokenId);
        console.log("Project Account deployed at: ", projectAccount);

        address projectRentalsCollection = blockEstate.projectsRentalsCollections(tokenId);
        console.log("Project Rentals Collection deployed at: ", projectRentalsCollection);

        blockEstate.setRentalAvailable(tokenId);
        

        vm.stopBroadcast();
        
    }
}
