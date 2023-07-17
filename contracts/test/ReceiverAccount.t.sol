// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "account-abstraction/interfaces/UserOperation.sol";
import "account-abstraction/core/EntryPoint.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";
import "account-abstraction/samples/DepositPaymaster.sol";
import "account-abstraction/test/TestToken.sol";
import "account-abstraction/test/TestOracle.sol";
import "forge-std/Test.sol";
import "../src/SourceAccount.sol";
import "../src/ReceiverAccount.sol";
import "../src/ReceiverAccountFactory.sol";
import "../src/InterChainSigData.sol";
import "./Sink.sol";
import "../src/InterChainPaymaster.sol";

// TODO split latter tests into `InterChainPaymaster.t.sol`
contract ReceiverAccountTest is Test {
    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;
    using InterChainSigDataLib for InterChainSigData;

    EntryPoint entrypoint;
    ReceiverAccountFactory accountFactory;
    ReceiverAccount receiverAccount;

    address owner;
    SourceAccount sourceAccount;

    Sink sink;

    address authorizedSpender;
    uint256 spenderKey;
    address beneficiary;
    address dummyPaymaster;
    DepositPaymaster paymaster;
    TestToken token;
    TestOracle oracle;
    InterChainPaymaster interchainPaymaster;

    // TODO: test on different chains (use succinct?)
    // uint256 sourceChainId = 1;
    uint256 sourceChainId = 2;
    uint256 remoteChainId = 2;

    function setUp() public {
        entrypoint = new EntryPoint();
        (authorizedSpender, spenderKey) = makeAddrAndKey("spender");
        accountFactory = new ReceiverAccountFactory(entrypoint);
        receiverAccount = accountFactory.createAccount(authorizedSpender, 0);

        owner = makeAddr("owner");
        sourceAccount = new SourceAccount(owner, address(entrypoint), authorizedSpender, address(1), address(1));

        sink = new Sink();
        beneficiary = makeAddr("beneficiary");
        dummyPaymaster = makeAddr("paymaster");
        paymaster = new DepositPaymaster(entrypoint);
        token = new TestToken();
        oracle = new TestOracle();
        vm.deal(dummyPaymaster, 5 ether);
        interchainPaymaster = new InterChainPaymaster(entrypoint, address(1), address(2));
    }

    function test_userOp() public {
        vm.chainId(remoteChainId);

        uint256 nonce = uint256(entrypoint.getNonce(address(receiverAccount), 0));

        // dummy chainID = 2, this chainid = 31337
        // TODO reconcile the value in sigdata and the msg.values
        InterChainSigData memory sigData = InterChainSigData(remoteChainId, sourceChainId, 0, 2 ether, "");

        bytes memory functionCallData = abi.encodeCall(Sink.sink, ());
        bytes memory walletCallData = abi.encodeCall(SimpleAccount.execute, (address(sink), 2 ether, functionCallData));

        UserOperation memory userOp = createAndSignInterChainUserOp(walletCallData, sigData);

        this.verifyInterUserOpSignature(userOp);

        uint256 accountBalance = address(receiverAccount).balance;
        uint256 sinkBalance = address(sink).balance;
        console.log("Account balance", accountBalance, "sink balance", sinkBalance);

        // Deposit prefund
        vm.deal(dummyPaymaster, 1 ether);
        vm.prank(dummyPaymaster);
        entrypoint.depositTo{value: 1 ether}(address(receiverAccount));
        console.log("dummyPaymaster balance", dummyPaymaster.balance);

        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;

        // TODO: can you use the deposit to fund msg.value?
        vm.deal(address(receiverAccount), 2 ether);
        entrypoint.handleOps(userOps, payable(beneficiary));

        console.log("Account balance", address(receiverAccount).balance, "sink balance", address(sink).balance);
    }

    error Signature(bytes);

    function test_paymaster() public {
        vm.chainId(remoteChainId);

        // Set up paymaster
        // Stake is for reputation/slashing
        paymaster.addStake{value: 2 ether}(1);
        paymaster.addToken(token, oracle);

        // Deposit is used to pay for gas, different from account's deposit in paymaster (ERC20)
        entrypoint.depositTo{value: 1 ether}(address(paymaster));

        // Set up token to pay for gas
        token.mint(address(receiverAccount), 5 ether);
        vm.prank(address(receiverAccount));
        // TODO can use permit?
        token.approve(address(paymaster), 10 ether);

        uint256 nonce = uint256(entrypoint.getNonce(address(receiverAccount), 0));

        // TODO reconcile the value in sigdata and the msg.values
        InterChainSigData memory sigData = InterChainSigData(remoteChainId, sourceChainId, 0, 2 ether, "");

        bytes memory functionCallData = abi.encodeCall(Sink.sink, ());
        bytes memory walletCallData = abi.encodeCall(SimpleAccount.execute, (address(sink), 2 ether, functionCallData));

        bytes memory paymasterAndData = abi.encodePacked(address(paymaster), address(token));

        UserOperation memory userOp =
            createAndSignInterChainUserOpPaymaster(walletCallData, sigData, paymasterAndData, 0);

        uint256 accountBalance = address(receiverAccount).balance;
        uint256 sinkBalance = address(sink).balance;
        console.log("Account balance", accountBalance, "sink balance", sinkBalance);

        // Works when gasFee is set to 0, this is what the JS tests are doing
        vm.expectRevert();
        entrypoint.simulateValidation(userOp);

        // Deposit prefund
        // TODO: can you use the deposit to fund msg.value?
        vm.prank(address(receiverAccount));
        paymaster.addDepositFor(token, address(receiverAccount), 1 ether);

        userOp = createAndSignInterChainUserOpPaymaster(walletCallData, sigData, paymasterAndData, 1);
        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;

        vm.deal(address(receiverAccount), 2 ether);
        entrypoint.handleOps(userOps, payable(beneficiary));
    }

    function test_interchainPaymaster() public {
        vm.chainId(remoteChainId);

        // Set up paymaster
        // Stake is for reputation/slashing
        interchainPaymaster.addStake{value: 2 ether}(1);
        // interchainPaymaster.addToken(token, oracle);

        // Deposit is used by the paymaster to pay for gas, different from account's deposit in interchainPaymaster (ERC20)
        entrypoint.depositTo{value: 1 ether}(address(interchainPaymaster));

        // Set up token to pay for gas
        token.mint(address(receiverAccount), 5 ether);
        vm.prank(address(receiverAccount));
        // TODO can use permit?
        token.approve(address(interchainPaymaster), 10 ether);

        uint256 nonce = uint256(entrypoint.getNonce(address(receiverAccount), 0));

        // TODO reconcile the value in sigdata and the msg.values
        InterChainSigData memory sigData = InterChainSigData(remoteChainId, sourceChainId, 0, 2 ether, "");

        bytes memory functionCallData = abi.encodeCall(Sink.sink, ());
        bytes memory walletCallData = abi.encodeCall(SimpleAccount.execute, (address(sink), 2 ether, functionCallData));

        bytes memory paymasterAndData = abi.encodePacked(address(interchainPaymaster), address(token));

        UserOperation memory userOp =
            createAndSignInterChainUserOpPaymaster(walletCallData, sigData, paymasterAndData, 1);

        uint256 accountBalance = address(receiverAccount).balance;
        uint256 sinkBalance = address(sink).balance;
        console.log("Account balance", accountBalance, "sink balance", sinkBalance);

        vm.prank(address(receiverAccount));
        // interchainPaymaster.addDepositFor(token, address(receiverAccount), 1 ether);

        // Failing because no eth funds
        vm.expectRevert();
        entrypoint.simulateHandleOp(userOp, address(0), "");

        // Should succeed
        vm.deal(address(interchainPaymaster), 2 ether);
        vm.expectRevert();
        interchainPaymaster.simulateFrontRun(userOp, address(0), "", 2 ether);

        sourceAccount.deposit{value: 2 ether}();

        // TODO add actual asserts here to check state
        console.log("Balance before", address(interchainPaymaster).balance, "source", address(sourceAccount).balance);
        console.log("receiver", address(receiverAccount).balance);
        console.log("Sink", address(sink).balance);
        interchainPaymaster.frontRunUserOp('', '', userOp, 2 ether);
        // interchainPaymaster.frontRunUserOp('', address(sourceAccount), userOp, 2 ether);
        console.log("Balance After", address(interchainPaymaster).balance, "source", address(sourceAccount).balance);
        console.log("receiver", address(receiverAccount).balance);
        console.log("Sink", address(sink).balance);
    }

    // TODO: customize interchain paymaster, go through chainID switches

    function hashInterSigAndOp(InterChainSigData calldata sigData, UserOperation calldata userOp)
        public
        pure
        returns (bytes32)
    {
        return sigData.hashWithUserOp(userOp);
    }

    function createAndSignInterChainUserOpPaymaster(
        bytes memory data,
        InterChainSigData memory sigData,
        bytes memory paymasterAndData,
        uint256 gasFee
    ) public view returns (UserOperation memory) {
        uint256 nonce = uint256(entrypoint.getNonce(address(receiverAccount), 0));
        UserOperation memory userOp = UserOperation(
            address(receiverAccount), nonce, "", data, 1000000, 1000000, 1000000, gasFee, 1000000, paymasterAndData, ""
        );

        bytes32 sigDataHash = this.hashInterSigAndOp(sigData, userOp);
        bytes32 interChainUserOpHash = keccak256(abi.encode(sigDataHash, entrypoint, sigData.remoteChainId));
        bytes32 hash = interChainUserOpHash.toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(spenderKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v); // note the order here is different from line above.
        sigData.signature = signature;
        userOp.signature = abi.encode(sigData);
        return userOp;
    }

    function createAndSignInterChainUserOp(bytes memory data, InterChainSigData memory sigData)
        public
        view
        returns (UserOperation memory)
    {
        uint256 nonce = uint256(entrypoint.getNonce(address(receiverAccount), 0));
        UserOperation memory userOp = UserOperation(
            address(receiverAccount), nonce, "", data, 1000000, 1000000, 1000000, 1000000, 1000000, "", ""
        );

        bytes32 sigDataHash = this.hashInterSigAndOp(sigData, userOp);
        bytes32 interChainUserOpHash = keccak256(abi.encode(sigDataHash, entrypoint, sigData.remoteChainId));
        bytes32 hash = interChainUserOpHash.toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(spenderKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v); // note the order here is different from line above.
        sigData.signature = signature;
        userOp.signature = abi.encode(sigData);
        return userOp;
    }

    function verifyInterUserOpSignature(UserOperation calldata userOp) public {
        // // We should have a minimum of 161 bytes if this is a cross-chain signature:
        // // 32 bytes for the source chain id
        // // 32 bytes for the source chain nonce
        // // a minimum of 32 bytes for the first allowed chain
        // // 65 bytes for the ECDSA signature
        // require(userOp.signature.length >= 161);

        InterChainSigData memory sigData = abi.decode(userOp.signature, (InterChainSigData));
        (address recoveredSigner, ECDSA.RecoverError error) = sigData.tryRecover(userOp, address(entrypoint));
        require(error == ECDSA.RecoverError.NoError);

        assertEq(recoveredSigner, authorizedSpender);
    }
}
