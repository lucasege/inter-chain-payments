// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "account-abstraction/samples/DepositPaymaster.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";
import "./SourceAccount.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";

contract InterChainPaymaster is BasePaymaster, AxelarExecutable {
    using UserOperationLib for UserOperation;
    IAxelarGasService public immutable gasService;

    constructor(IEntryPoint _entryPoint, address gateway_, address gasReceiver_) BasePaymaster(_entryPoint) AxelarExecutable(gateway_) {
        gasService = IAxelarGasService(gasReceiver_);
    }

    event PostOp(PostOpMode);

    function simulateFrontRun(
        UserOperation calldata op,
        address target,
        bytes calldata targetCallData,
        uint256 frontRunValue
    ) external {
        Address.sendValue(payable(op.sender), frontRunValue);
        // Must revert
        entryPoint.simulateHandleOp(op, target, targetCallData);
    }

    function crossChainVerify(UserOperation calldata op, string calldata destinationChain, string calldata destinationAddress) public payable {
        require(msg.value > 0, 'Gas payment is required');

        bytes memory payload = abi.encode(op);
        gasService.payNativeGasForContractCall{ value: msg.value }(
            address(this),
            destinationChain,
            destinationAddress,
            payload,
            msg.sender
        );
        gateway.callContract(destinationChain, destinationAddress, payload);
    }

    function frontRunUserOp(string calldata destinationChain, string calldata sourceAccount, UserOperation calldata op, uint256 frontRunValue) public payable {
        // TODO: make xchain
        this.crossChainVerify(op, destinationChain, sourceAccount);
        // source.spenderWithdraw(op);
        Address.sendValue(payable(op.sender), frontRunValue);

        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = op;

        entryPoint.handleOps(userOps, payable(address(this)));
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
