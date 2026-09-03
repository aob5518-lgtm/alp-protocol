"use client";

import {ReactNode, createContext, useContext, useEffect, useState} from "react";
import en from "../messages/en-US.json";
import zh from "../messages/zh-CN.json";

export type Locale = "en-US" | "zh-CN";
type WalletState = {address?: string; connect: () => Promise<void>; disconnect: () => void; error?: string};

export default function Providers({children}: {children: ReactNode}) {
  const [locale, setLocale] = useState<Locale>("en-US");
  const [address, setAddress] = useState<string>();
  const [error, setError] = useState<string>();
  const messages = locale === "zh-CN" ? zh : en;
  useEffect(() => {
    const provider = window.ethereum;
    if (!provider) return;
    provider.request({method: "eth_accounts"}).then((result) => setAddress((result as string[])[0])).catch(() => undefined);
    const onAccounts = (accounts: string[]) => setAddress(accounts[0]);
    provider.on?.("accountsChanged", onAccounts);
    return () => provider.removeListener?.("accountsChanged", onAccounts);
  }, []);
  const connect = async () => {
    const provider = window.ethereum;
    if (!provider) { setError("No injected wallet detected. Install MetaMask, TokenPocket or OKX Wallet."); return; }
    try {
      const accounts = await provider.request({method: "eth_requestAccounts"}) as string[];
      await provider.request({method: "wallet_switchEthereumChain", params: [{chainId: "0x61"}]});
      setAddress(accounts[0]); setError(undefined);
    } catch (cause) { setError(cause instanceof Error ? cause.message : "Wallet rejected the request."); }
  };
  return <TranslationContext.Provider value={messages as Record<string, unknown>}><LocaleContext.Provider value={{locale, setLocale}}><WalletContext.Provider value={{address, connect, disconnect: () => setAddress(undefined), error}}>{children}</WalletContext.Provider></LocaleContext.Provider></TranslationContext.Provider>;
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
declare global { interface Window { ethereum?: {request: (request: {method: string; params?: unknown[]}) => Promise<unknown>; on?: (event: string, listener: (accounts: string[]) => void) => void; removeListener?: (event: string, listener: (accounts: string[]) => void) => void}; } }
const WalletContext = createContext<WalletState>({connect: async () => undefined, disconnect: () => undefined});
export const useWallet = () => useContext(WalletContext);
