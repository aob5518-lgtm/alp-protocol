"use client";

import {ReactNode, createContext, useContext, useEffect, useState} from "react";
import {QueryClient, QueryClientProvider} from "@tanstack/react-query";
import {WagmiProvider, useConnection, useConnect, useDisconnect, useSwitchChain} from "wagmi";
import {bscTestnet} from "viem/chains";
import en from "../messages/en-US.json";
import zh from "../messages/zh-CN.json";
import {wagmiConfig} from "./wagmi";

export type Locale = "en-US" | "zh-CN";
type WalletStatus = "disconnected"|"connecting"|"connected"|"wrongNetwork"|"error";
type WalletState = {address?: string; connect: (connectorId:string) => Promise<void>; disconnect: () => void; error?: string; state:WalletStatus; connectors:{id:string;name:string}[]};

export default function Providers({children,initialLocale="en-US"}: {children: ReactNode;initialLocale?:Locale}) {
  const [queryClient] = useState(()=>new QueryClient());
  return <WagmiProvider config={wagmiConfig}><QueryClientProvider client={queryClient}><ProviderState initialLocale={initialLocale}>{children}</ProviderState></QueryClientProvider></WagmiProvider>;
}

function ProviderState({children,initialLocale}: {children: ReactNode;initialLocale:Locale}) {
  const [locale, setLocale] = useState<Locale>(initialLocale);
  const [errorKey, setErrorKey] = useState<"unavailable"|"rejected"|"failed">();
  const [connecting,setConnecting]=useState(false);
  const {address, chainId} = useConnection();
  const {connectAsync, connectors} = useConnect();
  const {disconnect} = useDisconnect();
  const {switchChainAsync} = useSwitchChain();
  const messages = locale === "zh-CN" ? zh : en;
  useEffect(() => {
    document.documentElement.lang = locale;
    document.title = messages.common.metadataTitle;
    document.querySelector('meta[name="description"]')?.setAttribute("content",messages.common.metadataDescription);
    try { window.localStorage.setItem("alp.locale", locale); } catch { /* Cookie remains authoritative when storage is restricted. */ }
    document.cookie = `alp.locale=${locale}; Path=/; Max-Age=31536000; SameSite=Lax`;
  }, [locale,messages]);
  const error=errorKey?messages.errors[errorKey]:undefined;
  const state:WalletStatus=connecting?"connecting":address?(chainId===bscTestnet.id?"connected":"wrongNetwork"):error?"error":"disconnected";
  const connect = async (connectorId:string) => {
    setConnecting(true);
    setErrorKey(undefined);
    try {
      const connector=connectors.find(candidate=>candidate.id===connectorId);
      if (!connector) {setErrorKey("unavailable");return;}
      await connectAsync({connector});
      if (chainId !== bscTestnet.id) await switchChainAsync({chainId:bscTestnet.id});
      setErrorKey(undefined);
    } catch (cause) {
      const code=(cause as {code?:number;cause?:{code?:number}}).code ?? (cause as {cause?:{code?:number}}).cause?.code;
      setErrorKey(code===4001?"rejected":"failed");
    } finally {setConnecting(false);}
  };
  return <TranslationContext.Provider value={messages as Record<string, unknown>}><LocaleContext.Provider value={{locale, setLocale}}><WalletContext.Provider value={{address, connect, disconnect, error, state, connectors:connectors.map(connector=>({id:connector.id,name:connector.name}))}}>{children}</WalletContext.Provider></LocaleContext.Provider></TranslationContext.Provider>;
}

const LocaleContext = createContext<{locale: Locale; setLocale: (locale: Locale) => void}>({locale: "en-US", setLocale: () => undefined});
export const useLocale = () => useContext(LocaleContext);
const TranslationContext = createContext<Record<string, unknown>>(en as Record<string, unknown>);
export function useTranslations(section: string) {
  const messages = useContext(TranslationContext);
  return (key: string, values: Record<string,string|number> = {}) => {
    const value = `${section}.${key}`.split(".").reduce<unknown>((current, part) => current && typeof current === "object" ? (current as Record<string, unknown>)[part] : undefined, messages);
    return typeof value === "string" ? value.replace(/\{(\w+)\}/g,(match,name:string)=>String(values[name]??match)) : key;
  };
}
const WalletContext = createContext<WalletState>({connect: async () => undefined, disconnect: () => undefined, state:"disconnected", connectors:[]});
export const useWallet = () => useContext(WalletContext);
