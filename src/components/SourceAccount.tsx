import { useAccount, useConnect, useNetwork, useWaitForTransaction, useWalletClient } from 'wagmi'
import { sourceAccountABI, usePrepareSourceAccountDeposit, useSourceAccountDeposit, useSourceAccountDeposits } from '../generated'
import SourceAccountContract from "../../contracts/out/SourceAccount.sol/SourceAccount.json";
import { useState } from 'react';

export function SourceAccountDeploy() {
    const { address } = useAccount()
    const { data: walletClient } = useWalletClient();
    const [sourceAccountHash, setSourceAccountHash] = useState<`0x${string}` | null>(null);
    let sourceAccountAddress = null;

    const storedAccountAddress = localStorage.getItem('SourceAccountAddress');
    if (storedAccountAddress !== null) {
        sourceAccountAddress = storedAccountAddress as `0x${string}`;
    }

    const deploySourceAccount = async () => {
        let sourceAccountBytecode = SourceAccountContract.bytecode.object as `0x${string}`;

        const hash = await walletClient?.deployContract({
            abi: sourceAccountABI,
            account: address,
            bytecode: sourceAccountBytecode,
            // TODO: replace hardcoded values
            args: ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "0xDF0CDa100E71C1295476B80f4bEa713D89C32691", "0x70997970C51812dc3A010C7d01b50e0d17dc79C8", "0x4F4495243837681061C4743b74B3eEdf548D56A5", "0x2d5d7d31F671F86C782533cc367F14109a082712"],
        })
        if (hash) {
            console.log("Hash", hash);
            setSourceAccountHash(hash);
        }
    }

    return (
        <div>
            SourceAccount
            <button onClick={deploySourceAccount}>Deploy SourceAccount</button>
            {sourceAccountHash !== null && <SourceAccountReadHash hash={sourceAccountHash} />}
            {sourceAccountAddress !== null && <SourceAccountReadAddress address={sourceAccountAddress} />}
        </div>
    )
}

export function SourceAccountReadHash({ hash }: { hash: `0x${string}` }) {
    const { data, isError, isLoading } = useWaitForTransaction({
        hash: hash
    })
    if (isLoading) return <div>Processing…</div>
    if (isError) return <div>Transaction error</div>
    console.log("Data", data)

    if (data?.contractAddress) {
        localStorage.setItem('SourceAccountAddress', data.contractAddress);
    }

    return <div>Nothing hash: {hash}</div>
}

const Deposit = ({ address }: { address: `0x${string}` }) => {
    const [depositValue, setDepositValue] = useState('');
    const { config } = usePrepareSourceAccountDeposit({
        address,
        value: BigInt(depositValue),
        enabled: Boolean(depositValue),
    })
    console.log("Deposit config", config);

    const { data, write } = useSourceAccountDeposit({
        ...config,
        onSuccess: () => setDepositValue(''),
    })

    const { refetch } = useSourceAccountDeposits({
        address
    });
    const { isLoading } = useWaitForTransaction({
        hash: data?.hash,
        onSuccess: () => refetch(),
    });

    const handleChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        const value = event.target.value;

        // Validate the input
        if (!isNaN(Number(value))) { // Only accept numeric inputs
            setDepositValue(value);
        } else {
            // Handle non-numeric input: display error message, or simply do nothing
        }
    };

    return (
        <div>
            Deposit:
            <input
                disabled={isLoading}
                onChange={handleChange}
                value={depositValue}
            />
            < button disabled={!write || isLoading
            } onClick={() => write?.()
            }>
                Send
            </button >
            {isLoading && <ProcessingMessage hash={data?.hash} />}
        </div>
    )
}

const ViewDeposits = ({ address }: { address: `0x${string}` }) => {
    const { data: deposits } = useSourceAccountDeposits({
        address
    });
    return <div>
        Deposits: {deposits?.toString()}
    </div>
}

export function SourceAccountReadAddress({ address }: { address: `0x${string}` }) {


    return (
        <div>
            <Deposit address={address} />
            <ViewDeposits address={address} />
        </div>
    )
}

function ProcessingMessage({ hash }: { hash?: `0x${string}` }) {
    const { chain } = useNetwork()
    const etherscan = chain?.blockExplorers?.etherscan
    return (
        <span>
            Processing transaction...{' '}
            {etherscan && (
                <a href={`${etherscan.url}/tx/${hash}`}>{etherscan.name}</a>
            )}
        </span>
    )
}