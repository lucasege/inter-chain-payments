import { BigNumberish, BytesLike, ethers } from "ethers";
import { entryPointABI, receiverAccountABI, receiverAccountFactoryABI, simpleNftABI, useEntryPointGetSenderAddress, useEntryPointGetUserOpHash, useEntryPointSimulateValidation, useInterChainPaymasterFrontRunUserOp, useInterChainPaymasterSimulateFrontRun, usePrepareEntryPointGetSenderAddress, usePrepareEntryPointHandleOps, usePrepareEntryPointSimulateValidation, usePrepareInterChainPaymasterFrontRunUserOp, usePrepareInterChainPaymasterSimulateFrontRun, usePrepareReceiverAccountValidateUserOp, usePrepareSimpleNftMintNft, useReceiverAccountFactoryGetAddress, useReceiverAccountFactoryGetInterChainSigHash, useReceiverAccountValidateUserOp, useSimpleNftBalanceOf, useSimpleNftName } from "../generated"
import { Web3 } from "web3";
import SimpleNFTABI from "../../contracts/out/SimpleNFT.sol/SimpleNFT.json";
import { IUserOperation, UserOperationBuilder } from "userop";
import { useAccount, useSignMessage, usePrepareContractWrite, useWalletClient, useConnect, useWaitForTransaction, useContractRead } from "wagmi";
import React, { useState } from "react";
import { recoverMessageAddress } from "viem";
import { localPolygonGanache, remoteChainId } from "../wagmi";



interface IMyUserOperation {
    sender: `0x${string}`;
    nonce: bigint;
    initCode: `0x${string}`;
    callData: `0x${string}`;
    callGasLimit: bigint;
    verificationGasLimit: bigint;
    preVerificationGas: bigint;
    maxFeePerGas: bigint;
    maxPriorityFeePerGas: bigint;
    paymasterAndData: `0x${string}`;
    signature: `0x${string}`;
}

interface InterChainSigData {
    remoteChainId: bigint;
    sourceChainId: bigint;
    remoteNonce: bigint;
    value: bigint;
    signature: `0x${string}`;
}
// To switch between networks:
// 0. Deploy new factory with the hash retrieval
// 1. Change aaddresses (interchainpaymaster, factory, authorized spender)
// 2. Change remote chain Id (in global setting and on sig data)
// 3. Change nonce for remote account (in two places)

const entrypointAddress = "0xDF0CDa100E71C1295476B80f4bEa713D89C32691";
// 0x01F04fe7f01bFe1887f284F06cdaf841a1E1D58C
const sourceAccountAddress = "0x89A4709eA55AC6dd5933b35Dd1881c924e47baA2";
// const interchainPaymasterAddress = "0x40ed70bFAC8AE48CBE838D978EA3312C31Fe5996";
const interchainPaymasterAddress = "0x12456Fa31e57F91B70629c1196337074c966492a";
// const receiverAccountFactoryAddress = "0x1b15E1f3c16BCc422314e13a9833339DE667216c";
const receiverAccountFactoryAddress = "0x1757a98c1333b9dc8d408b194b2279b5afdf70cc";
// const authorizedSpenderAddress = "0x5d2d2E1378178CAAA9029A224E89B3A66A288878";
const authorizedSpenderAddress = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
// const nftAddress = "0x86F9dFfe332BA023992E10D7cCffAAb60Ce08642"
const nftAddress = "0xfAFA2b1865629a7b8357CFbF231c7e9E54f4824D"
// let web3 = new Web3(Web3.givenProvider || "ws://localhost:8500/4");
let web3 = new Web3(Web3.givenProvider || "ws://localhost:8545");

export const NFTWindow = () => {
    const { data: walletClient } = useWalletClient();
    let provider = new ethers.JsonRpcProvider('http://localhost:8545');
    const contractABI = [
        "function getAddress(address owner, uint256 salt) view returns (address)"
    ];
    const receiverAccountFactoryContract = new ethers.Contract(receiverAccountFactoryAddress, contractABI, provider);

    const { address } = useAccount()
    const [userOperation, setUserOperation] = useState<IUserOperation | null>(null);

    const paymasterAndData = interchainPaymasterAddress;

    const buildUserOp = async () => {
        const senderAddress = await receiverAccountFactoryContract.getFunction("getAddress")(authorizedSpenderAddress, 0);
        const mintData = web3.eth.abi.encodeFunctionCall({
            stateMutability: 'payable',
            type: 'function',
            inputs: [
                { name: 'recipient', internalType: 'address', type: 'address' },
                { name: 'tokenURI', internalType: 'string', type: 'string' },
            ],
            name: 'mintNFT',
            outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
        }, [senderAddress, ""]);
        const executeData = web3.eth.abi.encodeFunctionCall({
            stateMutability: 'nonpayable',
            type: 'function',
            inputs: [
                { name: 'dest', internalType: 'address', type: 'address' },
                { name: 'value', internalType: 'uint256', type: 'uint256' },
                { name: 'func', internalType: 'bytes', type: 'bytes' },
            ],
            name: 'execute',
            outputs: [],
        }, [nftAddress, BigInt("100000000000000000"), mintData]);

        const initCode = ethers.concat([
            receiverAccountFactoryAddress,
            web3.eth.abi.encodeFunctionCall({
                inputs: [
                    {
                        internalType: "address",
                        name: "owner",
                        type: "address"
                    },
                    {
                        internalType: "uint256",
                        name: "salt",
                        type: "uint256"
                    }
                ],
                name: "createAccount",
                outputs: [
                    {
                        internalType: "contract ReceiverAccount",
                        name: "ret",
                        type: "address"
                    }
                ],
                stateMutability: "nonpayable",
                type: "function"
            }, [authorizedSpenderAddress, BigInt(0)])
        ]);
        // TODO nonce
        if (senderAddress) {
            console.log("Sender address", senderAddress)

            const builder = new UserOperationBuilder()
                .useDefaults({
                    sender: senderAddress,
                    callData: executeData,
                    initCode,
                    paymasterAndData,
                });
            // Build op with the middleware stack.
            const userOp = await builder.buildOp("0xDF0CDa100E71C1295476B80f4bEa713D89C32691", "31337");
            setUserOperation(userOp);
        }
    }
    console.log("UserOp building", userOperation)


    return (
        <div>
            NFTWINDOW
            <button onClick={buildUserOp}>Build USer OP</button>
            {userOperation != null &&
                <GenerateSignature userOp={userOperation} setUserOp={setUserOperation} />}
            < hr />
            {userOperation && userOperation.signature !== null && userOperation.signature !== "0x" && <div>
                <SimulateUserOP account={address} userOperation={userOperation} />
            </div>}
        </div>
    )
}

const GenerateSignature = ({ userOp, setUserOp }: { userOp: IUserOperation, setUserOp: any }) => {
    const { address: account } = useAccount()
    const { data: walletClient } = useWalletClient();

    const wrapperUserOperation: IMyUserOperation = {
        sender: userOp.sender as `0x${string}`,
        nonce: BigInt(userOp.nonce.toString()),
        initCode: userOp.initCode as `0x${string}`,
        callData: userOp.callData as `0x${string}`,
        callGasLimit: BigInt(300000n),
        verificationGasLimit: BigInt(500000n),
        preVerificationGas: BigInt(30000n),
        maxFeePerGas: BigInt(100000n),
        maxPriorityFeePerGas: BigInt(2n),
        paymasterAndData: userOp.paymasterAndData as `0x${string}`,
        signature: userOp.signature as `0x${string}`,
    }

    const interChainSigData: InterChainSigData = {
        remoteChainId: BigInt(31337),
        // remoteChainId: BigInt(2503n),
        sourceChainId: BigInt(2504n),
        remoteNonce: BigInt(0n),
        value: ethers.parseEther('0.1'),
        signature: "0x",
    };

    console.log("Interchain sig data", interChainSigData);

    const { isLoading: isHashLoading, data: hashData } = useReceiverAccountFactoryGetInterChainSigHash({
        address: receiverAccountFactoryAddress,
        args: [wrapperUserOperation, interChainSigData],
        onSuccess: (e) => {
            console.log("Success", e);
            // setUserOpHash(e);
        },
        onError: (e) => {
            console.log("Error", e);
        }
    })

    const signUserOp = async () => {
        if (hashData) {
            console.log("Signing hashdata!", hashData);
            if (walletClient && account) {
                //// !!!! Important -- this does the `toEthSignedMessage` conversion internally, so must be careful to not double dip.
                const sig = await walletClient.signMessage({
                    message: { raw: hashData },
                    account,
                });
                const newInterChainSigData: InterChainSigData = {
                    ...interChainSigData,
                    signature: sig,
                }
                const abiCoder = new ethers.AbiCoder();
                let types = ['uint256', 'uint256', 'uint256', 'uint256', 'bytes']
                let values = [
                    newInterChainSigData.remoteChainId.toString(),
                    newInterChainSigData.sourceChainId.toString(),
                    newInterChainSigData.remoteNonce.toString(),
                    newInterChainSigData.value.toString(),
                    newInterChainSigData.signature,
                ];

                let encoded = abiCoder.encode(types, values);
                // TODO fix this janky TS fix -- adding the struct offset manually.
                // I could fix this by just calling into the contract view to encode in solidity
                encoded = "0x0000000000000000000000000000000000000000000000000000000000000020" + encoded.substring(2);

                const newUserOp: IUserOperation = {
                    ...userOp,
                    signature: encoded,
                };
                setUserOp(newUserOp);
            }
        }
    }

    return (
        <div>
            {isHashLoading && <p>Loading...</p>}
            {!isHashLoading &&
                <button onClick={signUserOp}>Sign User OP</button>}
        </div>
    )
}


const SimulateUserOP = ({ account, userOperation }: { account: `0x${string}` | undefined, userOperation: IUserOperation }) => {
    const wrapperUserOperation: IMyUserOperation = {
        sender: userOperation.sender as `0x${string}`,
        nonce: BigInt(userOperation.nonce.toString()),
        initCode: userOperation.initCode as `0x${string}`,
        callData: userOperation.callData as `0x${string}`,
        callGasLimit: BigInt(300000n),
        verificationGasLimit: BigInt(500000n),
        preVerificationGas: BigInt(30000n),
        maxFeePerGas: BigInt(100000n),
        maxPriorityFeePerGas: BigInt(2n),
        paymasterAndData: userOperation.paymasterAndData as `0x${string}`,
        signature: userOperation.signature as `0x${string}`,
    }

    console.log("Wrapper user op", wrapperUserOperation)
    if (!account) {
        return <div>No account</div>
    }
    // 06/18/23: Working now with basic userOp signatures. Now I need to:
    // 1. DONE: Update the sig to be the interchainSigData fields and pass this in to Metamask
    // 2. DONE: Verify the sig on the account (Update the SCW and the factory)
    // 3. DONE: Integrate paymaster and figure out how to pass entrypoint

    const { data, config, error } = usePrepareInterChainPaymasterFrontRunUserOp({
        chainId: remoteChainId,
        address: interchainPaymasterAddress,
        account: account,
        args: [sourceAccountAddress, wrapperUserOperation, BigInt(web3.utils.toWei('0.1', 'ether'))],
    });

    const { write, error: writeError, data: writeData } = useInterChainPaymasterFrontRunUserOp(config);

    const { data: NFTBalanceData, refetch } = useSimpleNftBalanceOf({
        chainId: remoteChainId,
        address: nftAddress,
        args: [wrapperUserOperation.sender as `0x${string}`],
    });

    const { isLoading } = useWaitForTransaction({
        chainId: remoteChainId,
        hash: writeData?.hash,
        onSuccess: () => refetch(),
    });

    const simulateValidation = async () => {
        console.log("Simulating validation");
        write?.();
    }

    return (<div>
        <button onClick={simulateValidation}>Simulate this userOp</button>
        {isLoading}
        {NFTBalanceData != null && <div>
            {NFTBalanceData.toString()}
        </div>}
    </div>
    )
}