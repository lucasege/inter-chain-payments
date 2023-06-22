import { Chain, configureChains, createConfig } from 'wagmi'
import { foundry, goerli, mainnet } from 'wagmi/chains'
import { CoinbaseWalletConnector } from 'wagmi/connectors/coinbaseWallet'
import { InjectedConnector } from 'wagmi/connectors/injected'
import { MetaMaskConnector } from 'wagmi/connectors/metaMask'
import { WalletConnectConnector } from 'wagmi/connectors/walletConnect'

import { publicProvider } from 'wagmi/providers/public'

const walletConnectProjectId = '1'

export const localEthGanache = {
  id: 2503,
  name: 'Eth Ganache',
  network: 'Eth Ganache',
  nativeCurrency: {
    decimals: 18,
    name: 'gEthereum',
    symbol: 'gETH',
  },
  rpcUrls: {
    public: { http: ['http://127.0.0.1:8500/3'] },
    default: { http: ['http://127.0.0.1:8500/3'] },
  },
} as const satisfies Chain

export const localPolygonGanache = {
  id: 2504,
  name: 'Polygon Ganache',
  network: 'Ganache',
  nativeCurrency: {
    decimals: 18,
    name: 'gMatic',
    symbol: 'gMAT',
  },
  rpcUrls: {
    public: { http: ['http://127.0.0.1:8500/4'] },
    default: { http: ['http://127.0.0.1:8500/4'] },
  },
} as const satisfies Chain

export const sourceChainId = localEthGanache.id;
// export const remoteChainId = localPolygonGanache.id;
export const remoteChainId = 31337;

const { chains, publicClient, webSocketPublicClient } = configureChains(
  [
    mainnet,
    ...(import.meta.env?.MODE === 'development' ? [goerli, foundry] : []),
    localEthGanache, localPolygonGanache
  ],
  [
    publicProvider(),
  ],
)

export const config = createConfig({
  autoConnect: true,
  connectors: [
    new MetaMaskConnector({ chains }),
    new CoinbaseWalletConnector({
      chains,
      options: {
        appName: 'wagmi',
      },
    }),
    new WalletConnectConnector({
      chains,
      options: {
        projectId: walletConnectProjectId,
      },
    }),
    new InjectedConnector({
      chains,
      options: {
        name: 'Injected',
        shimDisconnect: true,
      },
    }),
  ],
  publicClient,
  webSocketPublicClient,
})
