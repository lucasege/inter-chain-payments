import { useState } from "react";
import { useAccount, useNetwork, useWaitForTransaction, useWalletClient } from "wagmi";
import { usePrepareReceiverAccountFactoryCreateAccount, useReceiverAccountFactoryCreateAccount } from "../generated";

export const ReceiverAccount = () => {
    const { address } = useAccount()
    const [receiverAccountHash, setReceiverAccountHash] = useState<`0x${string}` | null>(null);
    const receiverAccountFactoryAddress = import.meta.env.VITE_RECEIVER_ACCOUNT_FACTORY_ADDRESS as `0x${string}`;
    const authorizedSpenderAddress = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
    let receiverAccountAddress = null;

    const { config } = usePrepareReceiverAccountFactoryCreateAccount({
        address: receiverAccountFactoryAddress,
        account: address,
        args: [authorizedSpenderAddress, BigInt(0)],
        enabled: receiverAccountAddress === null,
    });

    const { data, write } = useReceiverAccountFactoryCreateAccount({
        ...config,
        onSuccess: (data) => setReceiverAccountHash(data?.hash),
    });

    const storedAccountAddress = localStorage.getItem('ReceiverAccountAddress');
    if (storedAccountAddress !== null) {
        receiverAccountAddress = storedAccountAddress as `0x${string}`;
    }

    return (
        <div>
            <button onClick={() => write?.()}>Deploy Receiver Account</button>
            {receiverAccountHash !== null && <ReceiverAccountReadHash hash={receiverAccountHash} />}
            {receiverAccountAddress !== null && <ReceiverAccountReadAddress address={receiverAccountAddress} />}
        </div>
    );
}
export function ReceiverAccountReadHash({ hash }: { hash: `0x${string}` }) {
    const { data, isError, isLoading } = useWaitForTransaction({
        hash: hash
    })
    if (isLoading) return <div>Processing…</div>
    if (isError) return <div>Transaction error</div>

    if (data?.logs && data?.logs.length > 0) {
        const address = data.logs[0].address;
        localStorage.setItem('ReceiverAccountAddress', address);
    }
    if (data?.contractAddress) {
        localStorage.setItem('ReceiverAccountAddress', data.contractAddress);
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