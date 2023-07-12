import { useState } from "react";
import { useAccount, useNetwork, useWaitForTransaction, useWalletClient } from "wagmi";
import { useEntryPointBalanceOf, useEntryPointDepositTo, useEntryPointDeposits, usePrepareEntryPointDepositTo, usePrepareReceiverAccountFactoryCreateAccount, useReceiverAccountFactoryCreateAccount } from "../generated";
import { remoteChainId } from "../wagmi";
import { ENTRYPOINT_ADDRESS, INTERCHAIN_PAYMASTER_ADDRESS } from "../utils/constants";

export const ReceiverAccount = () => {
    const { address } = useAccount()
    const [receiverAccountHash, setReceiverAccountHash] = useState<`0x${string}` | null>(null);
    const [receiverAccountAddress, setReceiverAccountAddress] = useState<`0x${string}` | null>(null);

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
            {INTERCHAIN_PAYMASTER_ADDRESS !== null && address != undefined && <DepositEntryPointReceiver interchainPaymasterAddress={INTERCHAIN_PAYMASTER_ADDRESS} account={address} />}
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
    const [depositValue, setDepositValue] = useState('');
    const { config } = usePrepareEntryPointDepositTo({
        chainId: remoteChainId,
        address: ENTRYPOINT_ADDRESS,
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
        address: ENTRYPOINT_ADDRESS,
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