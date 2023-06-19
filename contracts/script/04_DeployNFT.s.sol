// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/SimpleNFT.sol";

contract NFTTestDeploy is Script {
    // 0x86F9dFfe332BA023992E10D7cCffAAb60Ce08642
    bytes32 constant salt = keccak256("SimpleNFT");

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        SimpleNFT s = new SimpleNFT{salt: salt}();
        console.log("SimpleNFT address", address(s));
    }
}
