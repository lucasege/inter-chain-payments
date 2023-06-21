// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/InterChainPaymaster.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";

contract InterChainPaymasterScript is Script {
    // 0x30426D33a78afdb8788597D5BFaBdADc3Be95698
    bytes32 constant salt = keccak256("InterChainPaymaster2");

    address entrypoint = 0xDF0CDa100E71C1295476B80f4bEa713D89C32691; // Deterministic deployment

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        IEntryPoint e = IEntryPoint(entrypoint);
        InterChainPaymaster p = new InterChainPaymaster(e);
        console.log("Paymaster address", address(p));
    }
}
