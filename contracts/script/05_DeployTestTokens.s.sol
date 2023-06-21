pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "account-abstraction/test/TestToken.sol";
import "account-abstraction/test/TestOracle.sol";
import "../src/InterChainPaymaster.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";

contract TestTokenDeploy is Script {
    address payable interchainPaymaster = payable(0x77AD263Cd578045105FBFC88A477CAd808d39Cf6); // Deterministic deployment
    address entrypoint = 0xDF0CDa100E71C1295476B80f4bEa713D89C32691; // Deterministic deployment
    address sourceAccount = 0x89A4709eA55AC6dd5933b35Dd1881c924e47baA2; // Deterministic deployment
    address receiverAccount = 0xB9D6057f99802bc89B376733968619Eeb11B6B64; // can change;
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        TestToken t = new TestToken();
        TestOracle oracle = new TestOracle();
        console.log("Test token address", address(t));
        console.log("Test oracle address", address(oracle));

        // TODO move to some initialize functions:
        InterChainPaymaster paymaster = InterChainPaymaster(interchainPaymaster);
        paymaster.addStake{value: 2 ether}(1);
        paymaster.addToken(t, oracle);

        IEntryPoint e = IEntryPoint(entrypoint);
        e.depositTo{value: 1 ether}(interchainPaymaster);

        t.mint(receiverAccount, 5 ether);
    }

}