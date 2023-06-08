// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/ReceiverAccountFactory.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";

contract ReceiverAccountFactoryScript is Script {
    // 0x1656Fdd41Bcb972e0286dFd1958fED148f5057ab
    bytes32 constant salt = keccak256("ReceiverAccountFactory");

    address entrypoint = 0xDF0CDa100E71C1295476B80f4bEa713D89C32691; // Deterministic deployment

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        IEntryPoint e = IEntryPoint(entrypoint);
        ReceiverAccountFactory r = new ReceiverAccountFactory{salt: salt}(e);
        console.log("ReceiverAccountFactory address", address(r));
    }
}
