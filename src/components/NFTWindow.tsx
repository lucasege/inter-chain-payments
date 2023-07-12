import { ethers } from "ethers";
import { useInterChainPaymasterFrontRunUserOp, usePrepareInterChainPaymasterFrontRunUserOp, useReceiverAccountFactoryGetInterChainSigHash, useSimpleNftBalanceOf } from "../generated"
import { Web3 } from "web3";
import { IUserOperation, UserOperationBuilder } from "userop";
import { useAccount, useWalletClient, useWaitForTransaction } from "wagmi";
import { useState } from "react";
import { remoteChainId, sourceChainId } from "../wagmi";
import { AUTHORIZED_SPENDER_ADDRESS, ENTRYPOINT_ADDRESS, INTERCHAIN_PAYMASTER_ADDRESS, NFT_ADDRESS, RECEIVER_ACCOUNT_FACTORY_ADDRESS, SOURCE_ACCOUNT_ADDRESS, WEB3_PROVIDER_ADDRESS } from "../utils/constants";

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
// 1. Change addresses (interchainpaymaster, factory, authorized spender)
// 2. Change remote chain Id (in global setting and on sig data)
// 3. Change nonce for remote account (in two places)

let web3 = new Web3(Web3.givenProvider || `ws://${WEB3_PROVIDER_ADDRESS}`);

export const NFTWindow = () => {
    const { data: walletClient } = useWalletClient();
    let provider = new ethers.JsonRpcProvider(`http://${WEB3_PROVIDER_ADDRESS}`);
    const contractABI = [
        "function getAddress(address owner, uint256 salt) view returns (address)"
    ];
    const receiverAccountFactoryContract = new ethers.Contract(RECEIVER_ACCOUNT_FACTORY_ADDRESS, contractABI, provider);

    const { address } = useAccount()
    const [userOperation, setUserOperation] = useState<IUserOperation | null>(null);

    const paymasterAndData = INTERCHAIN_PAYMASTER_ADDRESS;

    const buildUserOp = async () => {
        const senderAddress = await receiverAccountFactoryContract.getFunction("getAddress")(AUTHORIZED_SPENDER_ADDRESS, 0);
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
        }, [NFT_ADDRESS, BigInt("100000000000000000"), mintData]);

        const initCode = ethers.concat([
            RECEIVER_ACCOUNT_FACTORY_ADDRESS,
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
            }, [AUTHORIZED_SPENDER_ADDRESS, BigInt(0)])
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
            const userOp = await builder.buildOp(ENTRYPOINT_ADDRESS, remoteChainId);
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
        remoteChainId: BigInt(remoteChainId),
        sourceChainId: BigInt(sourceChainId),
        remoteNonce: BigInt(0n),
        value: ethers.parseEther('0.1'),
        signature: "0x",
    };

    console.log("Interchain sig data", interChainSigData);

    const { isLoading: isHashLoading, data: hashData } = useReceiverAccountFactoryGetInterChainSigHash({
        address: RECEIVER_ACCOUNT_FACTORY_ADDRESS,
        args: [wrapperUserOperation, interChainSigData],
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
                // I could fix this by just calling into a contract view fn to encode in solidity
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

    const { data, config, error } = usePrepareInterChainPaymasterFrontRunUserOp({
        chainId: remoteChainId,
        address: INTERCHAIN_PAYMASTER_ADDRESS,
        account: account,
        args: [SOURCE_ACCOUNT_ADDRESS, wrapperUserOperation, BigInt(web3.utils.toWei('0.1', 'ether'))],
    });

    const { write, error: writeError, data: writeData } = useInterChainPaymasterFrontRunUserOp(config);

    const { data: NFTBalanceData, refetch } = useSimpleNftBalanceOf({
        chainId: remoteChainId,
        address: NFT_ADDRESS,
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