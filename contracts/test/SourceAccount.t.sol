// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "account-abstraction/interfaces/UserOperation.sol";
import "account-abstraction/core/EntryPoint.sol";
import "forge-std/Test.sol";
import "../src/SourceAccount.sol";
import "../src/InterChainSigData.sol";

// All working as expected although this contract surely has some bugs

contract SourceAccountTest is Test {
    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;
    using InterChainSigDataLib for InterChainSigData;

    SourceAccount account;
    address owner;
    address authorizedSpender;
    address paymaster;
    uint256 spenderKey;
    address imposter;
    EntryPoint entrypoint;

    function setUp() public {
        owner = vm.addr(1);
        (authorizedSpender, spenderKey) = makeAddrAndKey("spender");
        // authorizedSpender = vm.addr(2);
        imposter = makeAddr("imposter");
        paymaster = makeAddr("paymaster");
        entrypoint = new EntryPoint();
        vm.deal(owner, 100 ether);
        vm.deal(imposter, 1 ether);
        account = new SourceAccount(owner, address(entrypoint), authorizedSpender, address(1), address(1));
    }

    function test_startWithdrawFailsWrongOwner() public {
        vm.prank(imposter);
        vm.expectRevert("account: not Owner");
        account.startWithdraw(1 ether);
    }

    function test_starWithdrawFailsDepositTooLow() public {
        vm.prank(owner);
        vm.expectRevert("account: withdraw exceeds deposits");
        account.startWithdraw(1 ether);
    }

    function test_deposit() public {
        vm.prank(owner);
        account.deposit{value: 1 ether}();
        assertEq(account.deposits(), 1 ether);
    }

    function test_startWithdraw() public {
        assertEq(account.isWithdrawPending(), false);
        vm.prank(owner);
        account.deposit{value: 1 ether}();
        vm.prank(owner);
        account.startWithdraw(1 ether);

        // Shouldn't withdraw yet
        assertEq(account.deposits(), 1 ether);
        assertEq(account.isWithdrawPending(), true);
    }

    function test_withdraw() public {
        vm.prank(owner);
        account.deposit{value: 1 ether}();

        vm.prank(owner);
        account.startWithdraw(1 ether);

        assertEq(block.timestamp, 1);
        skip(account.withdrawPeriod());
        assertEq(block.timestamp, account.withdrawPeriod() + 1);

        assertEq(account.isWithdrawPending(), true);
        uint256 ownerBalanceBefore = owner.balance;
        uint256 accountBalanceBefore = address(account).balance;

        account.withdraw();

        assertEq(account.isWithdrawPending(), false);

        assertGt(owner.balance, ownerBalanceBefore);
        assertLt(address(account).balance, accountBalanceBefore);
        assertEq(account.deposits(), 0 ether);

        assertEq(account.withdrawTime(), 2 ** 256 - 1);
    }

    function hashInterSigAndOp(InterChainSigData calldata sigData, UserOperation calldata userOp)
        public
        pure
        returns (bytes32)
    {
        return sigData.hashWithUserOp(userOp);
    }

    function createAndSignInterChainUserOp(bytes memory data, InterChainSigData memory sigData)
        public
        view
        returns (UserOperation memory)
    {
        uint256 nonce = uint256(entrypoint.getNonce(address(account), 0));
        UserOperation memory userOp = UserOperation(
            address(account),
            nonce,
            "",
            data,
            1000000,
            1000000,
            1000000,
            1000000,
            1000000,
            abi.encodePacked(paymaster),
            ""
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

    function test_proveWithdraw() public {
        uint256 nonce = uint256(entrypoint.getNonce(address(account), 0));
        console.log("Nonce", nonce);
        console.log("Chain id", block.chainid);

        // dummy chainID = 2, this chainid = 31337
        InterChainSigData memory sigData = InterChainSigData(2, block.chainid, 0, 1 ether, "");
        // TODO
        UserOperation memory dummy = UserOperation(
            address(account),
            nonce,
            "",
            "",
            1000000,
            1000000,
            1000000,
            1000000,
            1000000,
            abi.encodePacked(paymaster),
            ""
        );

        bytes memory walletCallData = abi.encodeCall(SourceAccount.spenderWithdraw, (dummy));

        UserOperation memory userOp = createAndSignInterChainUserOp(walletCallData, sigData);

        this.verifyInterUserOpSignature(userOp);

        account.deposit{value: 1 ether}();

        bool success = account.proveWithdraw(userOp);
        assertEq(success, true);

        account.spenderWithdraw(userOp);

        assertEq(address(account).balance, 0 ether);
        assertEq(paymaster.balance, 1 ether);

        // Try again with 0.5 ether
        sigData = InterChainSigData(2, block.chainid, 0, 0.5 ether, "");
        // TODO
        dummy = UserOperation(
            address(account),
            nonce + 1,
            "",
            "",
            1000000,
            1000000,
            1000000,
            1000000,
            1000000,
            abi.encodePacked(paymaster),
            ""
        );

        walletCallData = abi.encodeCall(SourceAccount.spenderWithdraw, (dummy));

        userOp = createAndSignInterChainUserOp(walletCallData, sigData);

        this.verifyInterUserOpSignature(userOp);

        account.deposit{value: 1 ether}();

        success = account.proveWithdraw(userOp);
        assertEq(success, true);

        account.spenderWithdraw(userOp);

        assertEq(paymaster.balance, 1.5 ether);
        assertEq(address(account).balance, 0.5 ether);

        vm.prank(owner);
        account.startWithdraw(0.5 ether);
        skip(account.withdrawPeriod());
        account.withdraw();

        assertEq(address(account).balance, 0 ether);
    }
}
