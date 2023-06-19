// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "account-abstraction/samples/SimpleAccount.sol";

import "./InterChainSigData.sol";

contract ReceiverAccount is SimpleAccount {
    using ECDSA for bytes32;
    using InterChainSigDataLib for InterChainSigData;

    constructor(IEntryPoint anEntryPoint) SimpleAccount(anEntryPoint) {
    }

    function _validateSignature(UserOperation calldata userOp, bytes32)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        InterChainSigData memory sigData = abi.decode(userOp.signature, (InterChainSigData));
        (address recoveredSigner, ECDSA.RecoverError err) = sigData.tryRecover(userOp, address(entryPoint()));
        if (!(err == ECDSA.RecoverError.NoError && owner == recoveredSigner)) {
            return SIG_VALIDATION_FAILED;
        }

        require(sigData.remoteChainId == block.chainid, "account: Invalid source chain Id");
        // TODO
        // require(sigData.nonce is incremental);
        // require(sigData.remoteChainId is approved)

        return 0;
    }

    function getInterChainSigHash(UserOperation calldata userOp, InterChainSigData calldata sigData) external view returns (bytes32) {
        bytes32 hash = sigData.hashWithUserOp(userOp);
        bytes32 interChainUserOpHash = keccak256(abi.encode(hash, address(entryPoint()), sigData.remoteChainId));
        return interChainUserOpHash;
        // return interChainUserOpHash.toEthSignedMessageHash();
    }
}
