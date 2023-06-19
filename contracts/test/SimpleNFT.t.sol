// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "account-abstraction/interfaces/UserOperation.sol";
import "forge-std/Test.sol";
import "../src/SimpleNFT.sol";
import "../src/SourceAccount.sol";
import "../src/ReceiverAccount.sol";
import "../src/InterChainSigData.sol";
import "account-abstraction/core/EntryPoint.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SimpleNFTTest is Test {
    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;
    bytes32 constant receiverSalt = keccak256("ReceiverAccountFactory");

    SimpleNFT simpleNFT;
    ReceiverAccount receiver;
    EntryPoint e;
    address paymaster;

    function setUp() public {
        simpleNFT = new SimpleNFT();
        e = new EntryPoint();
        paymaster = makeAddr("paymaster");
        receiver = new ReceiverAccount{salt: receiverSalt}(e);
    }

    error Encoding(bytes);
    // Pseudo test just to compare with JS generated encoding

    // function test_Encoding() public {
    //     bytes memory nftCallData = abi.encodeCall(SimpleNFT.mintNFT, (0xb07C0EDf52dcc3075FF581016826B56c03c7A8d5, ""));
    //     // JS: 0xeacabe14000000000000000000000000b07c0edf52dcc3075ff581016826b56c03c7a8d500000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000
    //     // Sol: 0xeacabe14000000000000000000000000b07c0edf52dcc3075ff581016826b56c03c7a8d500000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000
    //     // revert Encoding(nftCallData);
    //     assertEq(
    //         nftCallData,
    //         "0xeacabe14000000000000000000000000b07c0edf52dcc3075ff581016826b56c03c7a8d500000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000"
    //     );
    // }
    error Signature(bytes);
    error Sig(bytes32);

    function test_signature() public {
        bytes32 hashData = 0x7fb1a7f67697ee74320ae1406a52c9fd28ec905a3ed7cf35658712604e2641dc;
        bytes32 hash = hashData.toEthSignedMessageHash();
        uint256 signerPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        address owner = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        // 0x4c5cd6df0fa8c8a808f963b1a035c4530d589350e60d624aa769ce5fd67a5d3f

        // userOpHash = keccak256(abi.encode(getHash(test), address(0xDF0CDa100E71C1295476B80f4bEa713D89C32691), 31337));
        assertEq(owner, hash.recover(signature));
        // revert Signature(signature);

        // From JS: 0xf56d88ef1254326cc63629c81ca68fd7ced1e6126e6913f281d493f2876bfaa157a868ae2caa400f46b07173e2f9479edd7de4fd0cb3e97421f91d67b16813281c
        // From Sol:0xf56d88ef1254326cc63629c81ca68fd7ced1e6126e6913f281d493f2876bfaa157a868ae2caa400f46b07173e2f9479edd7de4fd0cb3e97421f91d67b16813281c
    }

    function test_SimulateValidation() public {
        //"0x0a364193d11d1dd5b91158346bcd49d3654c924e80d459c719b84c5e35b72ca4647b5699ae2357aebc571a1fa1e11b84764f9e5f8dbfbd22b99e53c2f037288e1c"
        console.log("receiver", address(receiver));
        // (,"signature":"0x9b769e1ee40e0d9958a37bfda26fa9dd3a938315f3bd55036a815d9eff66f5b1731f9bdc74e5f002f61acf9f4fb1a23f2c9c4eadd3418ce3e58c0c48f3743dcb1b"})
        // 0x30272661e944c5d54895859dd9572d6dadd5cd36fbe1f30c540b124a5241b795
        UserOperation memory test =  UserOperation(
           address(0xDc833faEd04ebc2Dae367dBbb5Bdd5f000E32887)
           ,0, 
           "", 
           "0xb61d27f600000000000000000000000086f9dffe332ba023992e10d7ccffaab60ce08642000000000000000000000000000000000000000000000000016345785d8a000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000064eacabe14000000000000000000000000dc833faed04ebc2dae367dbbb5bdd5f000e328870000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            1000000, 
            1000000, 
            1000000,
             1000000, 
             1000000, 
             "",
             ""
            // "0xf56d88ef1254326cc63629c81ca68fd7ced1e6126e6913f281d493f2876bfaa157a868ae2caa400f46b07173e2f9479edd7de4fd0cb3e97421f91d67b16813281c"
        );
        // UserOperation memory test2 =  UserOperation(
        //    address(0xDc833faEd04ebc2Dae367dBbb5Bdd5f000E32887)
        //    ,0, 
        //    "", 
        //    "0xb61d27f600000000000000000000000086f9dffe332ba023992e10d7ccffaab60ce08642000000000000000000000000000000000000000000000000016345785d8a000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000064eacabe14000000000000000000000000dc833faed04ebc2dae367dbbb5bdd5f000e328870000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        //     1000000, 
        //     1000000, 
        //     1000000,
        //      1000000, 
        //      1000000, 
        //      "",
        //     ""
        // );


        address owner = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        bytes32 userOpHash = getUserOpHash(getHash(test));
        // 0x4c5cd6df0fa8c8a808f963b1a035c4530d589350e60d624aa769ce5fd67a5d3f
        revert Sig(userOpHash);
        bytes32 hash2 = userOpHash.toEthSignedMessageHash();
        console.log("Owner", owner);

        uint256 signerPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;


        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, hash2);
        bytes memory signature = abi.encodePacked(r, s, v);
        test.signature = signature;
        revert Signature(signature);

        userOpHash = getUserOpHash(getHash(test));
        // userOpHash = keccak256(abi.encode(getHash(test), address(0xDF0CDa100E71C1295476B80f4bEa713D89C32691), 31337));
        bytes32 hash = userOpHash.toEthSignedMessageHash();

        assertEq(owner, hash.recover(test.signature));


        // assertEq(hash, "0x500ce7e1557448f7d6bd3a49425761a754eba0a6f290f488915d90cc413c3de129745f8d5b9121232222a14cec9170ef0cdfb11f4e0c1a1ac2209c93bf2314ff1b");
        // console.log("length", 
        //      test.paymasterAndData.length);
        //      console.log("test", test.sender);
        // e.simulateValidation(test);

        // (address recoveredSigner, ECDSA.RecoverError err) = sigData.tryRecover(test, "0xDF0CDa100E71C1295476B80f4bEa713D89C32691");
    }

    function getUserOpHash(bytes32 userOpHash) public pure returns (bytes32) {
        return keccak256(abi.encode(userOpHash, address(0xDF0CDa100E71C1295476B80f4bEa713D89C32691), 31337));
    }

    // function getSender(UserOperation memory userOp) internal pure returns (address) {
    //     address data;
    //     //read sender from userOp, which is first userOp member (saves 800 gas...)
    //     assembly {data := calldataload(userOp)}
    //     return address(uint160(data));
    // }

    function pack(UserOperation memory userOp) internal pure returns (bytes memory ret) {
        address sender = userOp.sender;
        uint256 nonce = userOp.nonce;
        bytes32 hashInitCode = keccak256(userOp.initCode);
        bytes32 hashCallData = keccak256(userOp.callData);
        uint256 callGasLimit = userOp.callGasLimit;
        uint256 verificationGasLimit = userOp.verificationGasLimit;
        uint256 preVerificationGas = userOp.preVerificationGas;
        uint256 maxFeePerGas = userOp.maxFeePerGas;
        uint256 maxPriorityFeePerGas = userOp.maxPriorityFeePerGas;
        bytes32 hashPaymasterAndData = keccak256(userOp.paymasterAndData);

        return abi.encode(
            sender, nonce,
            hashInitCode, hashCallData,
            callGasLimit, verificationGasLimit, preVerificationGas,
            maxFeePerGas, maxPriorityFeePerGas,
            hashPaymasterAndData
        );
    }

    function getHash(UserOperation memory userOp) internal pure returns (bytes32) {
        return keccak256(pack(userOp));
    }
}
