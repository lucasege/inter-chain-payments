// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "account-abstraction/interfaces/UserOperation.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * InterChain Signature Data struct
 * @param remoteChainId the remote chain that will spend the approved funds.
 * @param sourceChainId the source chain that is sourcing these funds (block.chainId in verification).
 * @param remoteNonce unique value the sender uses to verify it is not a replay.
 * @param value the requested ETH funds
 * @param signature the signature data
 */
struct InterChainSigData {
    uint256 remoteChainId;
    uint256 sourceChainId;
    uint256 remoteNonce;
    uint256 value;
    bytes signature;
}

/**
 * Utility functions helpful when working with InterChainSigData structs.
 */
library InterChainSigDataLib {
    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;

    function packWithUserOp(InterChainSigData memory sigData, UserOperation calldata userOp)
        internal
        pure
        returns (bytes memory ret)
    {
        address sender = UserOperationLib.getSender(userOp);
        bytes32 hashInitCode = calldataKeccak(userOp.initCode);
        bytes32 hashCallData = calldataKeccak(userOp.callData);
        uint256 callGasLimit = userOp.callGasLimit;
        uint256 verificationGasLimit = userOp.verificationGasLimit;
        uint256 preVerificationGas = userOp.preVerificationGas;
        uint256 maxFeePerGas = userOp.maxFeePerGas;
        uint256 maxPriorityFeePerGas = userOp.maxPriorityFeePerGas;
        bytes32 hashPaymasterAndData = calldataKeccak(userOp.paymasterAndData);
        uint256 remoteChainId = sigData.remoteChainId;
        uint256 sourceChainId = sigData.sourceChainId;
        uint256 remoteNonce = sigData.remoteNonce;
        uint256 value = sigData.value;

        return abi.encode(
            sender,
            hashInitCode,
            hashCallData,
            callGasLimit,
            verificationGasLimit,
            preVerificationGas,
            maxFeePerGas,
            maxPriorityFeePerGas,
            hashPaymasterAndData,
            remoteChainId,
            sourceChainId,
            remoteNonce,
            value
        );
    }

    function hashWithUserOp(InterChainSigData memory sigData, UserOperation calldata userOp)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(packWithUserOp(sigData, userOp));
    }

    function tryRecover(InterChainSigData memory sigData, UserOperation calldata userOp, address entryPoint)
        internal
        pure
        returns (address, ECDSA.RecoverError)
    {
        bytes32 interChainUserOpHash =
            keccak256(abi.encode(hashWithUserOp(sigData, userOp), entryPoint, sigData.remoteChainId));
        bytes32 hash = interChainUserOpHash.toEthSignedMessageHash();
        return hash.tryRecover(sigData.signature);
    }
}
