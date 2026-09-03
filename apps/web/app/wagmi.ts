import {createConfig, http, injected} from "wagmi";
import {metaMask} from "wagmi/connectors/metaMask";
import {walletConnect} from "wagmi/connectors/walletConnect";
import {bscTestnet} from "viem/chains";

const walletConnectProjectId=process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID;
export const wagmiConfig=createConfig({
  chains:[bscTestnet],
  connectors:[
    metaMask(),
    injected(),
    ...(walletConnectProjectId?[walletConnect({projectId:walletConnectProjectId})]:[]),
  ],
  transports:{[bscTestnet.id]:http(process.env.NEXT_PUBLIC_BSC_TESTNET_RPC_URL)},
  ssr:true,
});
