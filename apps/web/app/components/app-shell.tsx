"use client";

import Link from "next/link";
import {usePathname} from "next/navigation";
import {ChevronDown, Copy, Globe2, Menu, Network, Wallet, X} from "lucide-react";
import {useEffect, useRef, useState} from "react";
import {createPortal} from "react-dom";
import {useLocale, useTranslations, useWallet} from "../providers";

const navigation=[
  ["explore","/app/explore"],["launch","/app/launch/relique"],["portfolio","/app/portfolio"],
  ["network","/app/network"],["protocol","/app/protocol"],["top100","/app/top100"],["nodes","/app/nodes"],
] as const;

export function LocaleSwitcher(){
  const {locale,setLocale}=useLocale(),t=useTranslations("common");
  const [open,setOpen]=useState(false);
  const ref=useRef<HTMLDivElement>(null);
  useEffect(()=>{
    if(!open)return;
    const close=(event:KeyboardEvent)=>{if(event.key==="Escape"){setOpen(false);ref.current?.querySelector("button")?.focus();}};
    const outside=(event:PointerEvent)=>{if(!ref.current?.contains(event.target as Node))setOpen(false);};
    document.addEventListener("keydown",close);document.addEventListener("pointerdown",outside);
    return()=>{document.removeEventListener("keydown",close);document.removeEventListener("pointerdown",outside);};
  },[open]);
  return <div className="locale" ref={ref}>
    <button className="locale-trigger" type="button" aria-label={t("language")} aria-haspopup="menu" aria-expanded={open} onClick={()=>setOpen(!open)}><Globe2 size={17} aria-hidden="true"/><span className="locale-label">{t(locale==="zh-CN"?"localeLabelZh":"localeLabelEn")}</span><ChevronDown className="locale-chevron" size={13}/></button>
    {open&&<><div className="locale-backdrop" onClick={()=>setOpen(false)}/><div className="locale-menu" role="menu" aria-label={t("language")}><p>{t("language")}</p>{(["en-US","zh-CN"] as const).map(value=><button type="button" key={value} role="menuitemradio" aria-checked={locale===value} className={locale===value?"active":""} onClick={()=>{setLocale(value);setOpen(false);}}>{t(value==="en-US"?"en":"zh")}{locale===value&&" ✓"}</button>)}<button className="locale-cancel" type="button" onClick={()=>setOpen(false)}>{t("cancel")}</button></div></>}
  </div>;
}

export function WalletButton(){
  const {address,connect,disconnect,connectors,error,state}=useWallet(),t=useTranslations("wallet"),e=useTranslations("errors");
  const [open,setOpen]=useState(false),[copied,setCopied]=useState(false),[copyError,setCopyError]=useState(false);
  const copy=async()=>{try{await navigator.clipboard.writeText(address!);setCopied(true);setCopyError(false);}catch{setCopyError(true);}};
  return <div className="wallet-wrap">
    <button className="wallet" onClick={()=>setOpen(!open)} disabled={state==="connecting"}>{address?<>{address.slice(0,6)}…{address.slice(-4)}<ChevronDown size={14}/></>:<><Wallet size={16}/>{t(state==="connecting"?"connecting":"connect")}</>}</button>
    {error&&<span className="wallet-error" role="alert">{error}</span>}
    {open&&createPortal(<div className="wallet-overlay"><button className="wallet-dismiss" aria-label={t("cancel")} onClick={()=>setOpen(false)}/><section className="wallet-dialog" role="dialog" aria-modal="true" aria-label={t(address?"address":"connectWallet")}><header><b>{t(address?"address":"connectWallet")}</b><button onClick={()=>setOpen(false)} aria-label={t("cancel")}><X size={16}/></button></header>
      {address?<><p>{address}</p><button onClick={()=>void copy()}><Copy size={14}/>{t(copied?"copied":"copyAddress")}</button>{copyError&&<p role="alert">{e("copy")}</p>}<a href={`https://testnet.bscscan.com/address/${address}`} target="_blank" rel="noreferrer">{t("viewBscScan")}</a><span><Network size={14}/>{t("network")}: {t("testnet")}</span><button onClick={()=>{disconnect();setOpen(false);}}>{t("disconnect")}</button></>:<>{connectors.map(connector=><button key={connector.id} onClick={()=>{void connect(connector.id);setOpen(false);}}>{connector.name}</button>)}{connectors.length===0&&<p>{t("noConnectors")}</p>}</>}
    </section></div>,document.body)}
  </div>;
}
export function AppShell({children,titleKey}:{children:React.ReactNode;titleKey:string}){
  const path=usePathname(),t=useTranslations("nav"),c=useTranslations("common"); const [more,setMore]=useState(false);
  return <main className="product-shell"><aside className="app-sidebar"><Link className="app-brand" href="/"><span>A</span><b>ALP</b></Link><nav>{navigation.map(([key,href])=><Link key={href} href={href} className={path===href?"active":""}>{t(key)}</Link>)}</nav></aside>
    <section className="app-main"><header className="app-topbar"><div className="breadcrumb"><Link href="/app/explore">ALP</Link><span>/</span><b>{t(titleKey)}</b></div><div className="top-actions"><LocaleSwitcher/><span className="network"><i/>{c("testnet")}</span><WalletButton/></div></header><div className="app-content">{children}</div></section>
    <nav className="mobile-nav app-mobile-nav">{navigation.slice(0,4).map(([key,href])=><Link href={href} key={key}>{t(key)}</Link>)}<button aria-expanded={more} onClick={()=>setMore(!more)}><Menu size={18}/>{t("more")}</button>{more&&<div className="more-menu">{navigation.slice(4).map(([key,href])=><Link key={href} href={href}>{t(key)}</Link>)}<LocaleSwitcher/></div>}</nav>
  </main>;
}
