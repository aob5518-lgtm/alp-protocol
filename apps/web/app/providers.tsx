"use client";

import {ReactNode, createContext, useContext, useEffect, useState} from "react";
import {QueryClient, QueryClientProvider} from "@tanstack/react-query";
import {WagmiProvider, useConnection, useConnect, useDisconnect, useSwitchChain} from "wagmi";
import {bscTestnet} from "viem/chains";
import en from "../messages/en-US.json";
import zh from "../messages/zh-CN.json";
import {wagmiConfig} from "./wagmi";

export type Locale = "en-US" | "zh-CN";
type WalletState = {address?: string; connect: () => Promise<void>; disconnect: () => void; error?: string};

export default function Providers({children}: {children: ReactNode}) {
  const [queryClient] = useState(()=>new QueryClient());
  return <WagmiProvider config={wagmiConfig}><QueryClientProvider client={queryClient}><ProviderState>{children}</ProviderState></QueryClientProvider></WagmiProvider>;
}

function ProviderState({children}: {children: ReactNode}) {
  const [locale, setLocale] = useState<Locale>("en-US");
  const [error, setError] = useState<string>();
  const {address, chainId} = useConnection();
  const {connectAsync, connectors} = useConnect();
  const {disconnect} = useDisconnect();
  const {switchChainAsync} = useSwitchChain();
  const messages = locale === "zh-CN" ? zh : en;
  useEffect(() => {
    const stored = window.localStorage.getItem("alp.locale");
    if (stored === "en-US" || stored === "zh-CN") setLocale(stored);
  }, []);
  useEffect(() => {
    document.documentElement.lang = locale;
    window.localStorage.setItem("alp.locale", locale);
  }, [locale]);
  const connect = async () => {
    try {
      const candidates=[...connectors].sort((left,right)=>(left.id==="metaMask"?0:1)-(right.id==="metaMask"?0:1));
      if (!candidates.length) throw new Error("No wallet connector is available. Install MetaMask, TokenPocket or OKX Wallet.");
      let connected=false, lastError:unknown;
      for (const connector of candidates) { try { await connectAsync({connector}); connected=true; break; } catch (cause) { lastError=cause; } }
      if (!connected) throw lastError ?? new Error("Wallet connection failed.");
      if (chainId !== bscTestnet.id) await switchChainAsync({chainId:bscTestnet.id});
      setError(undefined);
    } catch (cause) { const code=(cause as {code?:number}).code; setError(code===4001?"Wallet rejected the request.":cause instanceof Error?cause.message:"Wallet connection failed."); }
  };
  return <TranslationContext.Provider value={messages as Record<string, unknown>}><LocaleContext.Provider value={{locale, setLocale}}><WalletContext.Provider value={{address, connect, disconnect, error}}>{children}</WalletContext.Provider></LocaleContext.Provider></TranslationContext.Provider>;
}

const LocaleContext = createContext<{locale: Locale; setLocale: (locale: Locale) => void}>({locale: "en-US", setLocale: () => undefined});
export const useLocale = () => useContext(LocaleContext);
const TranslationContext = createContext<Record<string, unknown>>(en as Record<string, unknown>);
export function useTranslations(section: string) {
  const messages = useContext(TranslationContext);
  return (key: string) => {
    const value = `${section}.${key}`.split(".").reduce<unknown>((current, part) => current && typeof current === "object" ? (current as Record<string, unknown>)[part] : undefined, messages);
    return typeof value === "string" ? value : key;
  };
}
const WalletContext = createContext<WalletState>({connect: async () => undefined, disconnect: () => undefined});
export const useWallet = () => useContext(WalletContext);
