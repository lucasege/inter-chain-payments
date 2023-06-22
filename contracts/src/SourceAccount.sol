// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./InterChainSigData.sol";

import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";

contract SourceAccount is AxelarExecutable {
    using ECDSA for bytes32;
    using InterChainSigDataLib for InterChainSigData;

    address owner;
    address entrypoint;
    // An address (but perhaps not a valid EOA depending on the chain) that can spend funds
    address public authorizedSpender;

    // Eth
    uint256 public deposits;
    uint256 public withdrawTime;
    uint256 pendingWithdraw;
    uint256 public withdrawPeriod = 3 hours;

    uint256 MAX_UINT = 2 ** 256 - 1;
    IAxelarGasService public immutable gasService;

    string public value;

    constructor(
        address newOwner,
        address _entrypoint,
        address _authorizedSpender,
        address gateway_,
        address gasReceiver_
    ) AxelarExecutable(gateway_) {
        require(newOwner != address(0), "Invalid owner");
        require(_entrypoint != address(0), "account: Invalid entrypoint");
        owner = newOwner;
        entrypoint = _entrypoint;
        authorizedSpender = _authorizedSpender;
        withdrawTime = MAX_UINT;
        gasService = IAxelarGasService(gasReceiver_);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "account: not Owner");
        _;
    }

    // Handle Axelar executor actions
    function runProveWithdraw(
        string calldata destinationChain,
        string calldata destinationAddress,
        UserOperation calldata userOp
    ) external payable {
        bytes memory payload = abi.encode(userOp);
        if (msg.value > 0) {
            gasService.payNativeGasForContractCall{value: msg.value}(
                address(this), destinationChain, destinationAddress, payload, msg.sender
            );
        }
        gateway.callContract(destinationChain, destinationAddress, payload);
    }

    // Handles calls created by setAndSend. Updates this contract's value
    function _execute(string calldata sourceChain_, string calldata sourceAddress_, bytes calldata payload_)
        internal
        override
    {
        (UserOperation memory userOp) = abi.decode(payload_, (UserOperation));
        (uint256 remoteChainId, uint256 sourceChainId, uint256 remoteNonce, uint256 value, bytes memory sig) =
            abi.decode(userOp.signature, (uint256, uint256, uint256, uint256, bytes));
        InterChainSigData memory sigData = InterChainSigData(remoteChainId, sourceChainId, remoteNonce, value, sig);
        userOp.signature = abi.encode(sigData);
        this.spenderWithdraw(userOp);
    }

    // // Probably can't have this because it adds a race condition for the owner to prevent legal usage
    // // Maybe would work with a similar withdraw period, not necessary now.
    // function setAuthorizedSpender(address anAuthorizedSpender) public onlyOwner {
    //     authorizedSpender = anAuthorizedSpender;
    // }

    function deposit() public payable returns (uint256) {
        deposits += msg.value;
        return deposits;
    }

    function startWithdraw(uint256 value) public onlyOwner returns (uint256) {
        require(value <= deposits, "account: withdraw exceeds deposits");
        pendingWithdraw = value;
        withdrawTime = block.timestamp + withdrawPeriod;
        return pendingWithdraw;
    }

    function withdraw() public {
        require(block.timestamp >= withdrawTime);
        payable(owner).transfer(pendingWithdraw);
        deposits -= pendingWithdraw;
        pendingWithdraw = 0;
        withdrawTime = MAX_UINT;
    }

    function isWithdrawPending() public view returns (bool) {
        return pendingWithdraw != 0 && pendingWithdraw != MAX_UINT;
    }

    // To be used by the paymaster to withdraw funds with a signature from the source account
    function proveWithdraw(UserOperation calldata userOp) public view returns (bool) {
        InterChainSigData memory sigData = abi.decode(userOp.signature, (InterChainSigData));
        (address recoveredSigner, ECDSA.RecoverError err) = sigData.tryRecover(userOp, entrypoint);
        if (!(err == ECDSA.RecoverError.NoError && authorizedSpender == recoveredSigner)) {
            return false;
        }

        require(sigData.sourceChainId == block.chainid, "account: Invalid source chain Id");
        require(sigData.value <= deposits, "account: user spend exceeds available deposits");
        // TODO
        // require(sigData.nonce is incremental);
        // require(sigData.remoteChainId is approved)

        return true;
    }

    error UserOpError(UserOperation op);

    function spenderWithdraw(UserOperation calldata userOp) public {
        require(proveWithdraw(userOp), "account: Invalid signature");
        require(userOp.paymasterAndData.length >= 20, "account: Invalid paymaster");

        InterChainSigData memory sigData = abi.decode(userOp.signature, (InterChainSigData));

        // TODO encode the paymaster address in the sig data to avoid frontrunning
        require(address(this).balance >= sigData.value, "No funds");
        address paymaster = address(bytes20(userOp.paymasterAndData[:20]));
        payable(paymaster).transfer(sigData.value);
        deposits -= sigData.value;
    }

    function helper_hashSigData(InterChainSigData calldata sigData, UserOperation calldata userOp)
        public
        pure
        returns (bytes32)
    {
        return sigData.hashWithUserOp(userOp);
    }

    function helper_createAndSignInterChainUserOp(UserOperation calldata userOp, InterChainSigData memory sigData)
        public
        view
        returns (bytes32)
    {
        bytes32 sigDataHash = this.helper_hashSigData(sigData, userOp);
        bytes32 interChainUserOpHash = keccak256(abi.encode(sigDataHash, entrypoint, sigData.remoteChainId));
        bytes32 hash = interChainUserOpHash.toEthSignedMessageHash();

        return hash;
    }
}
