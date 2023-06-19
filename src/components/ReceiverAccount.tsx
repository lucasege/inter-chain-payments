import { useState } from "react";
import { useAccount, useNetwork, useWaitForTransaction, useWalletClient } from "wagmi";
import { useEntryPointBalanceOf, useEntryPointDepositTo, useEntryPointDeposits, usePrepareEntryPointDepositTo, usePrepareReceiverAccountFactoryCreateAccount, useReceiverAccountFactoryCreateAccount } from "../generated";

export const ReceiverAccount = () => {
    const { address } = useAccount()
    const [receiverAccountHash, setReceiverAccountHash] = useState<`0x${string}` | null>(null);
    // const receiverAccountFactoryAddress = import.meta.env.VITE_RECEIVER_ACCOUNT_FACTORY_ADDRESS as `0x${string}`;
    const receiverAccountFactoryAddress = "0x1b15E1f3c16BCc422314e13a9833339DE667216c";
    const authorizedSpenderAddress = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
    const [receiverAccountAddress, setReceiverAccountAddress] = useState<`0x${string}` | null>(null);
    // let receiverAccountAddress = null;


    const { config } = usePrepareReceiverAccountFactoryCreateAccount({
        address: receiverAccountFactoryAddress,
        account: address,
        // TODO handle nonce incrementing?
        args: [authorizedSpenderAddress, BigInt(0)],
        enabled: receiverAccountAddress === null,
    });

    const { data, write } = useReceiverAccountFactoryCreateAccount({
        ...config,
        onSuccess: (data) => setReceiverAccountHash(data?.hash),
    });

    const storedAccountAddress = localStorage.getItem('ReceiverAccountAddress');
    if (storedAccountAddress !== null && receiverAccountAddress !== storedAccountAddress) {
        setReceiverAccountAddress(storedAccountAddress as `0x${string}`);
    }

    const deployReceiverAccount = async () => {
        localStorage.removeItem('ReceiverAccountAddress');
        setReceiverAccountAddress(null);
        setReceiverAccountHash(null);
        write?.();
    }

    const setAddress = (address: `0x${string}`) => {
        setReceiverAccountAddress(address);
        setReceiverAccountHash(null);
    }

    return (
        <div>
            {receiverAccountAddress === null &&
                <button onClick={deployReceiverAccount}>Deploy Receiver Account</button>}
            {receiverAccountHash !== null && <ReceiverAccountReadHash hash={receiverAccountHash} setAddress={setAddress} />}
            {receiverAccountAddress !== null && <ReceiverAccountReadAddress address={receiverAccountAddress} />}
            {receiverAccountAddress !== null && address != undefined && <DepositEntryPointReceiver receiverAccountAddress={receiverAccountAddress} account={address} />}
        </div>
    );
}
export function ReceiverAccountReadHash({ hash, setAddress }: { hash: `0x${string}`, setAddress: any }) {
    const { data, isError, isLoading } = useWaitForTransaction({
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

const DepositEntryPointReceiver = ({ receiverAccountAddress, account }: { receiverAccountAddress: `0x${string}`, account: `0x${string}` }) => {
    console.log("Receiveraccount address", receiverAccountAddress);
    const entryPointAddress = "0xDF0CDa100E71C1295476B80f4bEa713D89C32691";
    const [depositValue, setDepositValue] = useState('');
    const { config } = usePrepareEntryPointDepositTo({
        address: entryPointAddress,
        account,
        value: BigInt(depositValue),
        args: [receiverAccountAddress],
        // What does this do
        enabled: true,
    });

    const { data, write } = useEntryPointDepositTo({
        ...config,
        onSuccess: (e) => {
            console.log("success deposit to", e);
        }
    });

    const { refetch } = useEntryPointBalanceOf({
        address: entryPointAddress,
        args: [receiverAccountAddress],
    });

    const { isLoading } = useWaitForTransaction({
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
            Deposit:
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