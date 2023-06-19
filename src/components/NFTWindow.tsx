import { BigNumberish, BytesLike, ethers } from "ethers";
import { entryPointABI, receiverAccountABI, simpleNftABI, useEntryPointGetUserOpHash, useEntryPointSimulateValidation, usePrepareEntryPointHandleOps, usePrepareEntryPointSimulateValidation, usePrepareReceiverAccountValidateUserOp, usePrepareSimpleNftMintNft, useReceiverAccountValidateUserOp, useSimpleNftBalanceOf, useSimpleNftName } from "../generated"
import { Web3 } from "web3";
import SimpleNFTABI from "../../contracts/out/SimpleNFT.sol/SimpleNFT.json";
import { IUserOperation, UserOperationBuilder } from "userop";
import { useAccount, useSignMessage, usePrepareContractWrite, useWalletClient, useConnect } from "wagmi";
import React, { useState } from "react";
import { recoverMessageAddress } from "viem";



interface MyIUserOperation {
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

export const NFTWindow = () => {
    const { address } = useAccount()
    let web3 = new Web3(Web3.givenProvider || "ws://localhost:8545");
    const [userOperation, setUserOperation] = useState<IUserOperation | null>(null);


    // let userOperation: IUserOperation | null = null;
    // let userOperation: any = null;


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

    const buildUserOp = async () => {
        // TODO nonce
        const builder = new UserOperationBuilder()
            .useDefaults({
                sender: receiverAccountAddress,
                callData: executeData,
            });
        // Build op with the middleware stack.
        const userOp = await builder.buildOp("0xDF0CDa100E71C1295476B80f4bEa713D89C32691", "31337");
        setUserOperation(userOp);
    }


    // UserOp(receiverAccountaddress, calldata: execute: safeMint)
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
    const { data, error, isLoading, signMessage, variables } = useSignMessage()

    React.useEffect(() => {
        ; (async () => {
            if (variables?.message && data) {
                // const recoveredAddress = await recoverMessageAddress({
                //     message: variables?.message,
                //     signature: data,
                // })
                // console.log("Receoveredaddress", recoveredAddress);
                // console.log("variables", variables);
                if (userOp) {
                    // userOperation.signature = data;
                    const newUserOp: IUserOperation = {
                        ...userOp,
                        signature: data,
                    };
                    console.log("data", data);
                    setUserOp(newUserOp);
                    console.log("User operation", userOp);
                }
                // setUserOperation(userOperation);
                // setRecoveredAddress(recoveredAddress)
            }
        })()
    }, [data, variables?.message])

    const wrapperUserOperation: MyIUserOperation = {
        sender: userOp.sender as `0x${string}`,
        nonce: BigInt(userOp.nonce.toString()),
        initCode: userOp.initCode as `0x${string}`,
        callData: userOp.callData as `0x${string}`,
        callGasLimit: BigInt(3n),
        verificationGasLimit: BigInt(500000n),
        preVerificationGas: BigInt(30000n),
        maxFeePerGas: BigInt(100000n),
        maxPriorityFeePerGas: BigInt(2n),
        paymasterAndData: userOp.paymasterAndData as `0x${string}`,
        signature: userOp.signature as `0x${string}`,
    }

    const { isLoading: isHashLoading, data: hashData } = useEntryPointGetUserOpHash({
        address: "0xDF0CDa100E71C1295476B80f4bEa713D89C32691",
        args: [wrapperUserOperation],
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
                const sig = await walletClient.signMessage({
                    message: { raw: hashData },
                    account,
                });
                const newUserOp: IUserOperation = {
                    ...userOp,
                    signature: sig,
                };
                setUserOp(newUserOp);
                console.log("Sig from wallet client", sig);
            }

            // signMessage({ message: hashData });
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
    let web3 = new Web3(Web3.givenProvider || "ws://localhost:8545");
    const { connector } = useAccount();
    const { data: walletClient } = useWalletClient();
    // let wrapperUserOperation: MyIUserOperation = {
    //     sender: "0x",
    //     nonce: BigInt(0),
    //     initCode: "0x",
    //     callData: "0x",
    //     callGasLimit: BigInt(0),
    //     verificationGasLimit: BigInt(0),
    //     preVerificationGas: BigInt(0),
    //     maxFeePerGas: BigInt(0),
    //     maxPriorityFeePerGas: BigInt(0),
    //     paymasterAndData: "0x",
    //     signature: "0x"

    // };
    // if (userOperation) {
    const wrapperUserOperation: MyIUserOperation = {
        sender: userOperation.sender as `0x${string}`,
        nonce: BigInt(userOperation.nonce.toString()),
        initCode: userOperation.initCode as `0x${string}`,
        callData: userOperation.callData as `0x${string}`,
        callGasLimit: BigInt(3n),
        // callGasLimit: BigInt(userOperation.callGasLimit.toString()),
        verificationGasLimit: BigInt(500000n),
        // verificationGasLimit: BigInt(userOperation.verificationGasLimit.toString()),
        preVerificationGas: BigInt(30000n),
        // preVerificationGas: BigInt(userOperation.preVerificationGas.toString()),
        maxFeePerGas: BigInt(100000n),
        // maxFeePerGas: BigInt(userOperation.maxFeePerGas.toString()),
        maxPriorityFeePerGas: BigInt(2n),
        // maxPriorityFeePerGas: BigInt(userOperation.maxPriorityFeePerGas.toString()),
        paymasterAndData: userOperation.paymasterAndData as `0x${string}`,
        signature: userOperation.signature as `0x${string}`,
        // signature: "0x0f3cfe867d970567fe82212f77a0fa9e3242d7702b68e55bd6332f42a8dfb21920f3b31a949a6c11dce49684d88a20cdc31445dcc398e6ba5ee1dd76182c6c7f1b",
    }

    // console.log("hashData", hashData);
    console.log("Wrapper user op", wrapperUserOperation)
    // }
    if (!account) {
        return <div>No account</div>
    }

    // const { data, config, error } = usePrepareEntryPointHandleOps({
    //     address: "0xDF0CDa100E71C1295476B80f4bEa713D89C32691",
    //     account,
    //     args: [[wrapperUserOperation], account],
    //     enabled: true
    // });

    const { data, config, error } = usePrepareEntryPointSimulateValidation({
        address: "0xDF0CDa100E71C1295476B80f4bEa713D89C32691",
        account: account,
        args: [wrapperUserOperation],
        enabled: true,
        gas: 10000000n,
        gasPrice: 100000000n,
    });
    console.log("Data", data)
    console.log("Config", config)
    console.log("Error", error);
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
    // console.log("Simulation data", data);

    const simulateValidation = async () => {
        console.log("Simulating validation");
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