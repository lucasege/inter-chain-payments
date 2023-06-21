import { useState } from "react";
import { useAccount, useNetwork, useWaitForTransaction, useWalletClient } from "wagmi";
import { useEntryPointBalanceOf, useEntryPointDepositTo, useEntryPointDeposits, usePrepareEntryPointDepositTo, usePrepareReceiverAccountFactoryCreateAccount, useReceiverAccountFactoryCreateAccount } from "../generated";
import { remoteChainId } from "../wagmi";

export const ReceiverAccount = () => {
    const { address } = useAccount()
    const [receiverAccountHash, setReceiverAccountHash] = useState<`0x${string}` | null>(null);
    // const receiverAccountFactoryAddress = import.meta.env.VITE_RECEIVER_ACCOUNT_FACTORY_ADDRESS as `0x${string}`;
    const interchainPaymasterAddress = "0xDBfD5A731b744Aad08a4238387910B9ca7BddcB0";
    const receiverAccountFactoryAddress = "0x1b15E1f3c16BCc422314e13a9833339DE667216c";
    // TODO use address?
    const authorizedSpenderAddress = "0x5d2d2E1378178CAAA9029A224E89B3A66A288878";
    const [receiverAccountAddress, setReceiverAccountAddress] = useState<`0x${string}` | null>(null);
    // let receiverAccountAddress = null;


    // const { config } = usePrepareReceiverAccountFactoryCreateAccount({
    //     address: receiverAccountFactoryAddress,
    //     account: address,
    //     chainId: remoteChainId,
    //     // TODO handle nonce incrementing?
    //     args: [authorizedSpenderAddress, BigInt(0)],
    //     enabled: receiverAccountAddress === null,
    // });

    // const { data, write } = useReceiverAccountFactoryCreateAccount({
    //     ...config,
    //     onSuccess: (data) => setReceiverAccountHash(data?.hash),
    // });

    // const storedAccountAddress = localStorage.getItem('ReceiverAccountAddress');
    // if (storedAccountAddress !== null && receiverAccountAddress !== storedAccountAddress) {
    //     setReceiverAccountAddress(storedAccountAddress as `0x${string}`);
    // }

    // const deployReceiverAccount = async () => {
    //     localStorage.removeItem('ReceiverAccountAddress');
    //     setReceiverAccountAddress(null);
    //     setReceiverAccountHash(null);
    //     write?.();
    // }

    const setAddress = (address: `0x${string}`) => {
        setReceiverAccountAddress(address);
        setReceiverAccountHash(null);
    }

    return (
        <div>
            {/* {receiverAccountAddress === null &&
                <button onClick={deployReceiverAccount}>Deploy Receiver Account</button>} */}
            {receiverAccountHash !== null && <ReceiverAccountReadHash hash={receiverAccountHash} setAddress={setAddress} />}
            {receiverAccountAddress !== null && <ReceiverAccountReadAddress address={receiverAccountAddress} />}
            {interchainPaymasterAddress !== null && address != undefined && <DepositEntryPointReceiver interchainPaymasterAddress={interchainPaymasterAddress} account={address} />}
        </div>
    );
}
export function ReceiverAccountReadHash({ hash, setAddress }: { hash: `0x${string}`, setAddress: any }) {
    const { data, isError, isLoading } = useWaitForTransaction({
        chainId: remoteChainId,
        hash: hash
    })
    if (isLoading) return <div>Processing…</div>
    if (isError) return <div>Transaction error</div>
    console.log("Data", data);

    if (data?.logs && data?.logs.length > 0) {
        const address = data.logs[0].address;
        localStorage.setItem('ReceiverAccountAddress', address);
        setAddress(address);
    }
    if (data?.contractAddress) {
        localStorage.setItem('ReceiverAccountAddress', data.contractAddress);
        setAddress(data?.contractAddress);
    }

    return <div>Nothing hash: {hash}</div>
}

export function ReceiverAccountReadAddress({ address }: { address: `0x${string}` }) {

    return (
        <div>
            ReceiverAccount address:
            {address}
        </div>
    )
}

const DepositEntryPointReceiver = ({ interchainPaymasterAddress, account }: { interchainPaymasterAddress: `0x${string}`, account: `0x${string}` }) => {
    const entryPointAddress = "0xDF0CDa100E71C1295476B80f4bEa713D89C32691";
    // const interchainPaymasterAddress = "0xDBfD5A731b744Aad08a4238387910B9ca7BddcB0";
    const [depositValue, setDepositValue] = useState('');
    const { config } = usePrepareEntryPointDepositTo({
        chainId: remoteChainId,
        address: entryPointAddress,
        account,
        value: BigInt(depositValue),
        args: [interchainPaymasterAddress],
        enabled: true,
    });

    const { data, write } = useEntryPointDepositTo({
        ...config,
        onSuccess: (e) => {
            console.log("success deposit to", e);
        }
    });

    const { refetch } = useEntryPointBalanceOf({
        chainId: remoteChainId,
        address: entryPointAddress,
        args: [interchainPaymasterAddress],
    });

    const { isLoading } = useWaitForTransaction({
        chainId: remoteChainId,
        hash: data?.hash,
        onSuccess: () => refetch(),
    });

    // TODO call when page loads
    const refreshBalance = async () => {
        const test = await refetch();
        console.log("Tests", test);
        if (test.data) {
            setDepositValue(test.data.toString());
        }
    }


    const handleChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        const value = event.target.value;

        if (!isNaN(Number(value))) {
            setDepositValue(value);
        }
    };

    return (
        <div>
            Deposit For paymaster {interchainPaymasterAddress}:
            <input disabled={isLoading}
                onChange={handleChange}
                value={depositValue}
            />
            < button disabled={!write || isLoading} onClick={() => write?.()}>
                Send</button>

            <hr />
            Deposits: {depositValue?.toString()}
            <button onClick={refreshBalance} >Refresh</button>
            {isLoading && <div>Processing</div>}
        </div>
    )

}