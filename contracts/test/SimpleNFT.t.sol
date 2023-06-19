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
    using InterChainSigDataLib for InterChainSigData;

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

    function takeCalldata(UserOperation calldata userOp, InterChainSigData memory sigData) internal {
        (address recoveredSigner, ECDSA.RecoverError err) = sigData.tryRecover(userOp, address(0xDF0CDa100E71C1295476B80f4bEa713D89C32691));
        console.log("Recovered signer", recoveredSigner);
    }

    function test_recoverSigData() public {
        UserOperation memory userOp = UserOperation(
            address(0x99427343b498bec656Dd4670101bb018f1855aCA),
            0,
            "",
            hex"b61d27f600000000000000000000000086f9dffe332ba023992e10d7ccffaab60ce08642000000000000000000000000000000000000000000000000016345785d8a000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000064eacabe1400000000000000000000000099427343b498bec656dd4670101bb018f1855aca0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            3,
            500000,
            30000,
            100000,
            2,
            "",
            ""
        );
        // InterChainSigData memory sigData = InterChainSigData(31337, 31337, 0, 0.1 ether, "");
        userOp.signature = hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000007a690000000000000000000000000000000000000000000000000000000000007a690000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000016345785d8a000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000041fb193d797a5f357409224abf6b37a0e89267157c27b5ef54cfa03eae789a529e02aa79dc87cf7991f140604b310cc9b62ad9fcfeed28df37b7881be1cb8cb0af1b00000000000000000000000000000000000000000000000000000000000000";

        this.verifyInterUserOpSignature(userOp);
        // (address recoveredSigner, ECDSA.RecoverError err) = sigData.tryRecover(userOp, address(0xDF0CDa100E71C1295476B80f4bEa713D89C32691));
        // console.log("Recovered signer", recoveredSigner);
    }

    function verifyInterUserOpSignature(UserOperation calldata userOp) public {
        // // We should have a minimum of 161 bytes if this is a cross-chain signature:
        // // 32 bytes for the source chain id
        // // 32 bytes for the source chain nonce
        // // a minimum of 32 bytes for the first allowed chain
        // // 65 bytes for the ECDSA signature
        // require(userOp.signature.length >= 161);

        InterChainSigData memory sigData = abi.decode(userOp.signature, (InterChainSigData));
        console.log("Sig data remotechain ", sigData.remoteChainId);
        console.log("sourcechainid", sigData.sourceChainId);
        console.log("nonce", sigData.remoteNonce);
        console.log("Value", sigData.value);
        (address recoveredSigner, ECDSA.RecoverError error) = sigData.tryRecover(userOp, address(0xDF0CDa100E71C1295476B80f4bEa713D89C32691));
        require(error == ECDSA.RecoverError.NoError);
        console.log("RecoveredSigner", recoveredSigner);

        // assertEq(recoveredSigner, authorizedSpender);
    }

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
        
        // from interchain sigdata JS: 0x6f052e3b9cccd14333d045175ff9fba0ee61a164c60d79d884f890d6b4eaf7c3
        // Sig: 0x11698b31d7048b7bb5ebf8a7409fb5b0585e1919d9f60936d28edf48066687d818a6777e32d4de00da80a7aad01a64118d890a70e6e0c84eff5a56c3b1d723701b


        // 0000000000000000000000000000000000000000000000000000000000007a69 // 1 remoteChainId
        // 0000000000000000000000000000000000000000000000000000000000007a69 // 2 Sourcechainid
        // 0000000000000000000000000000000000000000000000000000000000000000 // 3 remotenonce
        // 000000000000000000000000000000000000000000000000016345785d8a0000 // 4 value
        // 00000000000000000000000000000000000000000000000000000000000000a0 // 5 signature: first position, then sig
        // 0000000000000000000000000000000000000000000000000000000000000041 // 6
        // 11698b31d7048b7bb5ebf8a7409fb5b0585e1919d9f60936d28edf48066687d8 // 7
        // 18a6777e32d4de00da80a7aad01a64118d890a70e6e0c84eff5a56c3b1d72370 // 8
        // 1b00000000000000000000000000000000000000000000000000000000000000 // 9


        // 0000000000000000000000000000000000000000000000000000000000000020
        // 0000000000000000000000000000000000000000000000000000000000007a69
        // 0000000000000000000000000000000000000000000000000000000000007a69
        // 0000000000000000000000000000000000000000000000000000000000000000
        // 000000000000000000000000000000000000000000000000016345785d8a0000
        // 00000000000000000000000000000000000000000000000000000000000000a0
        // 0000000000000000000000000000000000000000000000000000000000000041
        // e012656ff4c4b9e761d10eee7d4bee3da43fe913225a13210a6d8af66799d953
        // 3e0723e349cc804e2fa6efb9a59d47908e6b41c22c0f1aba50cdcc97f071cd34
        // 1b00000000000000000000000000000000000000000000000000000000000000

        // 0000000000000000000000000000000000000000000000000000000000000020 // 1  0x00
        // 0000000000000000000000000000000000000000000000000000000000000002 // 2  0x20 remotechainId
        // 0000000000000000000000000000000000000000000000000000000000000002 // 3  0x40 sourcechainId
        // 0000000000000000000000000000000000000000000000000000000000000000 // 4  0x60 remoteNonce
        // 0000000000000000000000000000000000000000000000001bc16d674ec80000 // 5  0x80 value
        // 00000000000000000000000000000000000000000000000000000000000000a0 // 6  0xa0 Signature offset (from 0x20)
        // 0000000000000000000000000000000000000000000000000000000000000041 // 7  0xc0 Signature length (65 bytes)
        // 1e84845253d34c2635286ecefa415853ad3f6c932c80617031bdb694f3684893 // 8  0xe0 first 32
        // 5d3f0b27822af848cb17815559aad70991df3239f2fde788cbb7eed7f3ef2a13 // 9  0x100 second 32
        // 1b00000000000000000000000000000000000000000000000000000000000000 // 10 0x120 last byte + 0s

        // "0x0000000000000000000000000000000000000000000000000000000000007a690000000000000000000000000000000000000000000000000000000000007a690000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000016345785d8a000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000004111698b31d7048b7bb5ebf8a7409fb5b0585e1919d9f60936d28edf48066687d818a6777e32d4de00da80a7aad01a64118d890a70e6e0c84eff5a56c3b1d723701b00000000000000000000000000000000000000000000000000000000000000"
        // "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001bc16d674ec8000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000411e84845253d34c2635286ecefa415853ad3f6c932c80617031bdb694f36848935d3f0b27822af848cb17815559aad70991df3239f2fde788cbb7eed7f3ef2a131b00000000000000000000000000000000000000000000000000000000000000"
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
