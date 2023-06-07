import { useAccount } from 'wagmi'

import { Account } from './components/Account'
import { Connect } from './components/Connect'
import { Counter } from './components/Counter'
import { NetworkSwitcher } from './components/NetworkSwitcher'
import { SourceAccount } from './components/SourceAccount'

export function App() {
  const { isConnected } = useAccount()

  return (
    <>
      <h1>wagmi + Vite</h1>


      <Connect />

      {isConnected && (
        <>
          <Account />
          <hr />
          {/* Deploy SourceAccount on L1 */}
          {/* Allow depositing into SourceAccount on L1 */}
          <SourceAccount />

          <hr />

          {/* Deploy ReceiverAccount on L2 */}
          {/* <ReceiverAccount /> */}

          {/* Simple NFT deploy (if not exists) or interaction on l2 */}
          {/* <NFTWindow /> */}

          {/* Intent creation window */}
          {/* IntentWindow */}

          {/* Deploy SourceAccount on L1 */}
          {/* Deploy SourceAccount on L1 */}
          <Counter />
          <hr />
          <NetworkSwitcher />
        </>
      )}
    </>
  )
}
