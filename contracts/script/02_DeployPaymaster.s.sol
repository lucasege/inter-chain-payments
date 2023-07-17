// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/InterChainPaymaster.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";

contract InterChainPaymasterScript is Script {
    // 0x30426D33a78afdb8788597D5BFaBdADc3Be95698
    bytes32 constant salt = keccak256("InterChainPaymaster");

    function setUp() public {}

    function run() public {
        address entrypoint = vm.envAddress("ENTRYPOINT");
        address axelarGateway = vm.envAddress("AXELAR_GATEWAY");
        address axelarGasService = vm.envAddress("AXELAR_GAS_SERVICE");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        IEntryPoint e = IEntryPoint(entrypoint);
        InterChainPaymaster p = new InterChainPaymaster(e, axelarGateway, axelarGasService);
        console.log("Paymaster address", address(p));
    }
}
