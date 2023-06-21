import { BigNumberish, BytesLike, ethers } from "ethers";
import { entryPointABI, receiverAccountABI, receiverAccountFactoryABI, simpleNftABI, useEntryPointGetSenderAddress, useEntryPointGetUserOpHash, useEntryPointSimulateValidation, useInterChainPaymasterSimulateFrontRun, usePrepareEntryPointGetSenderAddress, usePrepareEntryPointHandleOps, usePrepareEntryPointSimulateValidation, usePrepareInterChainPaymasterSimulateFrontRun, usePrepareReceiverAccountValidateUserOp, usePrepareSimpleNftMintNft, useReceiverAccountFactoryGetAddress, useReceiverAccountGetInterChainSigHash, useReceiverAccountValidateUserOp, useSimpleNftBalanceOf, useSimpleNftName } from "../generated"
import { Web3 } from "web3";
import SimpleNFTABI from "../../contracts/out/SimpleNFT.sol/SimpleNFT.json";
import { IUserOperation, UserOperationBuilder } from "userop";
import { useAccount, useSignMessage, usePrepareContractWrite, useWalletClient, useConnect } from "wagmi";
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

const interchainPaymasterAddress = "0xDBfD5A731b744Aad08a4238387910B9ca7BddcB0";
const receiverAccountFactoryAddress = "0x1b15E1f3c16BCc422314e13a9833339DE667216c";
const authorizedSpenderAddress = "0x5d2d2E1378178CAAA9029A224E89B3A66A288878";
let web3 = new Web3(Web3.givenProvider || "ws://localhost:8500/4");

export const NFTWindow = () => {
    const { data: walletClient } = useWalletClient();

    const { address } = useAccount()
    const [userOperation, setUserOperation] = useState<IUserOperation | null>(null);

    const nftAddress = import.meta.env.VITE_NFT_ADDRESS;
    const receiverAccountAddress = localStorage.getItem("ReceiverAccountAddress") as `0x${string}`;
    if (receiverAccountAddress == null) {
        return <div>
            Please deploy a Receiver Account first.
        </div>
    }

    const { data: NFTBalanceData } = useSimpleNftBalanceOf({
        address: nftAddress,
        args: [receiverAccountAddress as `0x${string}`],
    })
    // Create userOp that includes safeMint call...
    // Use userop.js to create a userOp with calldata = encodeFunctionCall('execute', )
    const mintData = web3.eth.abi.encodeFunctionCall({
        stateMutability: 'payable',
        type: 'function',
        inputs: [
            { name: 'recipient', internalType: 'address', type: 'address' },
            { name: 'tokenURI', internalType: 'string', type: 'string' },
        ],
        name: 'mintNFT',
        outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    }, [receiverAccountAddress, ""]);
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
    const paymasterAndData = interchainPaymasterAddress;
    const { isLoading: senderAddressLoading, data: senderAddress } = useReceiverAccountFactoryGetAddress({
        address: receiverAccountFactoryAddress,
        account: address,
        chainId: remoteChainId,
        args: [authorizedSpenderAddress, BigInt(0)],
        onSuccess: (e) => {
            console.log("Success getting address", e);
        }
    })

    const buildUserOp = async () => {
        // TODO nonce
        if (!senderAddressLoading && senderAddress) {
            // write?.();
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


    // Then call into metamask to sign this from the approved signer account
    // Then call Interchainpaymaster to simulate this transaction
    // const { config } = usePrepareSimpleNftMintNft({
    //     address: nftAddress,
    //     account: receiverAccountAddress,
    //     args: [receiverAccountAddress, ""],
    //     enabled: receiverAccountAddress != null,
    //     value: BigInt("100000000000000000"),
    // });
    // console.log("Config", config)

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
    // const { data, error, isLoading, signMessage, variables } = useSignMessage()

    // React.useEffect(() => {
    //     ; (async () => {
    //         if (variables?.message && data) {
    //             if (userOp) {
    //                 const newUserOp: IUserOperation = {
    //                     ...userOp,
    //                     signature: data,
    //                 };
    //                 console.log("data", data);
    //                 setUserOp(newUserOp);
    //                 console.log("User operation", userOp);
    //             }
    //         }
    //     })()
    // }, [data, variables?.message])

    const wrapperUserOperation: IMyUserOperation = {
        sender: userOp.sender as `0x${string}`,
        nonce: BigInt(userOp.nonce.toString()),
        initCode: userOp.initCode as `0x${string}`,
        callData: userOp.callData as `0x${string}`,
        callGasLimit: BigInt(30000n),
        verificationGasLimit: BigInt(500000n),
        preVerificationGas: BigInt(30000n),
        maxFeePerGas: BigInt(100000n),
        maxPriorityFeePerGas: BigInt(2n),
        paymasterAndData: userOp.paymasterAndData as `0x${string}`,
        signature: userOp.signature as `0x${string}`,
    }

    const interChainSigData: InterChainSigData = {
        remoteChainId: BigInt(2503n),
        sourceChainId: BigInt(2504n),
        remoteNonce: BigInt(0n),
        value: ethers.parseEther('0.1'),
        signature: "0x",
    };

    console.log("Interchain sig data", interChainSigData);

    const { isLoading: isHashLoading, data: hashData } = useReceiverAccountGetInterChainSigHash({
        address: userOp.sender as `0x${string}`,
        args: [wrapperUserOperation, interChainSigData],
        onSuccess: (e) => {
            console.log("Success", e);
            // setUserOpHash(e);
        },
        onError: (e) => {
            console.log("Error", e);
        }
    })

    // const { isLoading: isHashLoading, data: hashData } = useEntryPointGetUserOpHash({
    //     address: "0xDF0CDa100E71C1295476B80f4bEa713D89C32691",
    //     args: [wrapperUserOperation],
    //     onSuccess: (e) => {
    //         console.log("Success", e);
    //         // setUserOpHash(e);
    //     },
    //     onError: (e) => {
    //         console.log("Error", e);
    //     }
    // })

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
        callGasLimit: BigInt(30000n),
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
    // 3. Integrate paymaster and figure out how to pass entrypoint

    // const { data, config, error } = usePrepareEntryPointHandleOps({
    //     address: "0xDF0CDa100E71C1295476B80f4bEa713D89C32691",
    //     account,
    //     args: [[wrapperUserOperation], account],
    //     enabled: true
    // });

    // TODO: June 21
    // Seems to just be throwing a basic revert. Probably next step is to just do away with hooks and
    // Call directly from ethers and try to interpret revert reason

    // const { data, config, error } = usePrepareEntryPointSimulateValidation({
    const { data, config, error } = usePrepareInterChainPaymasterSimulateFrontRun({
        address: interchainPaymasterAddress,
        account: account,
        args: [wrapperUserOperation, "0x0000000000000000000000000000000000000000", "0x", BigInt(web3.utils.toWei('0.1', 'ether'))],
        enabled: false,
        gas: 10000000n,
        gasPrice: 100000000n,
    });
    console.log("Data", data)
    console.log("Config", config)
    console.log("Error", error);
    const { write, error: writeErro, data: writeData } = useInterChainPaymasterSimulateFrontRun(config);
    // const receiverAccountAddress = localStorage.getItem("ReceiverAccountAddress") as `0x${string}`;
    // const { data, config, error } = usePrepareReceiverAccountValidateUserOp({
    //     address: receiverAccountAddress,
    //     account: account,
    //     args: [wrapperUserOperation, "0x4c5cd6df0fa8c8a808f963b1a035c4530d589350e60d624aa769ce5fd67a5d3f", BigInt(0)],
    // })
    // const { data, config, error } = usePrepareContractWrite({
    //     address: '0xDF0CDa100E71C1295476B80f4bEa713D89C32691',
    //     account: account,
    //     abi: entryPointABI,
    //     functionName: 'simulateValidation',
    //     args: [wrapperUserOperation],
    // })
    // console.log("Data',", data)
    // console.log("simulate config", config);
    // console.log("Simualte error", error);
    // const { data, write } = useEntryPointSimulateValidation({
    //     ...config,
    //     onSuccess: (a: any) => {
    //         console.log("Success simulating");
    //         console.log("anything", a);
    //     },
    //     onError: (e: any) => {
    //         console.log("Error simulating, ", e);
    //     }
    // })
    console.log("writerror ", writeErro);
    console.log("Write data", writeData);
    // console.log("Simulation data", data);

    const simulateValidation = async () => {
        console.log("Simulating validation");
        write?.();
        console.log("writerror ", writeErro);
        console.log("Write data", writeData);
        // const res = await walletClient?.sendTransaction({
        //     to: "0xDF0CDa100E71C1295476B80f4bEa713D89C32691",
        //     account: account,
        //     data: validateData as `0x${string}`,
        //     gas: 10000000n,
        //     gasPrice: 100000000000n,
        // });
        // const transactionData = {
        //     from: account,
        //     to: '0xDF0CDa100E71C1295476B80f4bEa713D89C32691',
        //     value: web3.utils.toWei('0.1', 'ether'),
        //     data: validateData,
        //     gas: 21000, // Gas limit
        //     gasPrice: web3.utils.toWei('100', 'gwei'), // Gas price in Wei
        // };
        // console.log("Finished", res);
        // console.log("Simualte write", write);
        // write?.();
    }

    return (<div>
        <button onClick={simulateValidation}>Simulate this userOp</button>
    </div>
    )
}