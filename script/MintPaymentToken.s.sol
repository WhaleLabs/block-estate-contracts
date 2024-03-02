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
    MockERC20 public paymentToken;
    

    function setUp() public {}

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        paymentToken = MockERC20(0xbA397eFEF3914aB025F7f5706fADE61f240A9EbC);
        paymentToken.mint(0x000ef5F21dC574226A06C76AAE7060642A30eB74, 2000000000000 ether);

        
        

        vm.stopBroadcast();
        
    }
}
