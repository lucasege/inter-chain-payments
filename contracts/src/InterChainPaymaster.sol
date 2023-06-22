// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "account-abstraction/samples/DepositPaymaster.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";
import "./SourceAccount.sol";

contract InterChainPaymaster is BasePaymaster {
    using UserOperationLib for UserOperation;
    // TODO generalize to include a mapping of `SourceAccount -> authorizedSpender`
    // SourceAccount source;
    // address[] sourceAccounts;

    // constructor(IEntryPoint _entryPoint) DepositPaymaster(_entryPoint) {
    constructor(IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {
        // source = SourceAccount(_sourceAccount);
    }

    event PostOp(PostOpMode);

    function simulateFrontRun(
        UserOperation calldata op,
        address target,
        bytes calldata targetCallData,
        uint256 frontRunValue
    ) external {
        Address.sendValue(payable(op.sender), frontRunValue);
        // TODO: should I catch the revert here? and revert again?
        // Must revert
        entryPoint.simulateHandleOp(op, target, targetCallData);
    }

    function frontRunUserOp(address sourceAccount, UserOperation calldata op, uint256 frontRunValue) public {
        // TODO: make xchain
        // SourceAccount source = SourceAccount(sourceAccount);
        // bool success = source.proveWithdraw(op);
        // if (success) {
            // TODO: actually make interchain call here
            // source.spenderWithdraw(op);
            Address.sendValue(payable(op.sender), frontRunValue);

            UserOperation[] memory userOps = new UserOperation[](1);
            userOps[0] = op;

            entryPoint.handleOps(userOps, payable(address(this)));
        // }
    }

    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost) internal view override returns (bytes memory context, uint256 validationData) {
        // TODO: In theory this would be where you could call the cross-chain check, however that probably violates the
        // Entrypoint's requirements for idempotency and state access.
        // Instead it might be easier to just add another call on the paymaster, e.g. `registerUserOp` that will call into the
        // Source account, verify the claim and set some state on the paymaster and an expiration time
        // If postop is needed, send context
        return ("", 0);
    }

    function _postOp(PostOpMode mode, bytes calldata, uint256) internal virtual override {
        emit PostOp(mode);
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
