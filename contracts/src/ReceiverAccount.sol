// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "account-abstraction/samples/SimpleAccount.sol";

import "./InterChainSigData.sol";

contract ReceiverAccount is SimpleAccount {
    using ECDSA for bytes32;
    using InterChainSigDataLib for InterChainSigData;
    /// implement template method of BaseAccount

    // IEntryPoint private immutable _entryPoint;

    constructor(IEntryPoint anEntryPoint) SimpleAccount(anEntryPoint) {
        // _entryPoint = anEntryPoint;
        // _disableInitializers();
    }

    function _validateSignature(UserOperation calldata userOp, bytes32)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        // bytes32 hash = userOpHash.toEthSignedMessageHash();
        // if (owner != hash.recover(userOp.signature)) {
        //     return SIG_VALIDATION_FAILED;
        // }
        // return 0;

        InterChainSigData memory sigData = abi.decode(userOp.signature, (InterChainSigData));
        (address recoveredSigner, ECDSA.RecoverError err) = sigData.tryRecover(userOp, address(entryPoint()));
        if (!(err == ECDSA.RecoverError.NoError && owner == recoveredSigner)) {
            return SIG_VALIDATION_FAILED;
        }

        require(sigData.remoteChainId == block.chainid, "account: Invalid source chain Id");
        // require(sigData.value <= deposits, "account: user spend exceeds available deposits");
        // TODO
        // require(sigData.nonce is incremental);
        // require(sigData.remoteChainId is approved)

        return 0;
    }
}
