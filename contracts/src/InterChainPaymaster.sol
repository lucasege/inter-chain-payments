// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "account-abstraction/samples/DepositPaymaster.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";
import "./SourceAccount.sol";

contract InterChainPaymaster is DepositPaymaster {
    // TODO generalize to include a mapping of `SourceAccount -> authorizedSpender`
    SourceAccount source;

    constructor(IEntryPoint _entryPoint, address _sourceAccount) DepositPaymaster(_entryPoint) {
        source = SourceAccount(_sourceAccount);
    }

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

    function frontRunUserOp(UserOperation calldata op, uint256 frontRunValue) public {
        bool success = source.proveWithdraw(op);
        if (success) {
            // TODO: actually make interchain call here
            source.spenderWithdraw(op);
            Address.sendValue(payable(op.sender), frontRunValue);

            UserOperation[] memory userOps = new UserOperation[](1);
            userOps[0] = op;

            entryPoint.handleOps(userOps, payable(address(this)));
        }
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
