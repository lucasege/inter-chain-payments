// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "account-abstraction/core/EntryPoint.sol";

contract DeployEntrypointScript is Script {
    // Entrypoint address: 0xDF0CDa100E71C1295476B80f4bEa713D89C32691
    bytes32 constant salt = keccak256("Entrypoint");

    function setUp() public {}

    function run() public {
        vm.broadcast();
        EntryPoint e = new EntryPoint{salt: salt}();
        console.log("Entrypoint address", address(e));
    }
}
