// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/SourceAccount.sol";

contract SourceAccountScript is Script {
    // 0x89A4709eA55AC6dd5933b35Dd1881c924e47baA2
    bytes32 constant salt = keccak256("SourceAccount");

    // Goerli
    address owner = 0xc290dF1503612FeE1ecC683992D12D0B05466B2e; // Account 1
    address entrypoint = 0x0576a174D229E3cFA37253523E645A78A0C91B57; // Deterministic deployment
    address authorizedSpender = 0x5d2d2E1378178CAAA9029A224E89B3A66A288878; // Account 2
    address axelarGateway = 0xe432150cce91c13a887f7D836923d5597adD8E31; // Ganache Eth
    address axelarGasService = 0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6; // Ganahche Eth
    // TODO: read from env
    // address owner = 0x5d2d2E1378178CAAA9029A224E89B3A66A288878; // Account 1
    // address entrypoint = 0xDF0CDa100E71C1295476B80f4bEa713D89C32691; // Deterministic deployment
    // address authorizedSpender = 0x5d2d2E1378178CAAA9029A224E89B3A66A288878; // Account 2
    // address axelarGateway = 0x013459EC3E8Aeced878C5C4bFfe126A366cd19E9; // Ganache Eth
    // address axelarGasService = 0x28f8B50E1Be6152da35e923602a2641491E71Ed8; // Ganahche Eth

    // address authorizedSpender = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Account 2
    // address axelarGateway = 0x4F4495243837681061C4743b74B3eEdf548D56A5; // Forked from mainnet
    // address axelarGasService = 0x2d5d7d31F671F86C782533cc367F14109a082712; // Forked from mainnet

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        SourceAccount s =
            new SourceAccount{salt:salt}(owner, entrypoint, authorizedSpender, axelarGateway, axelarGasService);
        console.log("Source account address", address(s));
        vm.stopBroadcast();
    }
}
