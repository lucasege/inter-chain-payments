// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/SourceAccount.sol";

contract SourceAccountScript is Script {
    // 0x89A4709eA55AC6dd5933b35Dd1881c924e47baA2
    bytes32 constant salt = keccak256("SourceAccount");
    // TODO: read from env
    address owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Account 1
    address entrypoint = 0xDF0CDa100E71C1295476B80f4bEa713D89C32691; // Deterministic deployment
    address authorizedSpender = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Account 2
    address axelarGateway = 0x4F4495243837681061C4743b74B3eEdf548D56A5; // Forked from mainnet
    address axelarGasService = 0x2d5d7d31F671F86C782533cc367F14109a082712; // Forked from mainnet

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        SourceAccount s =
            new SourceAccount{salt:salt}(owner, entrypoint, authorizedSpender, axelarGateway, axelarGasService);
        console.log("Source account address", address(s));
    }
}
