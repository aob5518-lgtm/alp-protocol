"use client";

import Link from "next/link";
import {usePathname} from "next/navigation";
import {ChevronDown, Copy, Globe2, Menu, Network, Wallet, X} from "lucide-react";
import {useState} from "react";
import {useLocale, useTranslations, useWallet} from "../providers";

const navigation=[
  ["Explore","/app/explore"],["Launch","/app/launch/relique"],["Portfolio","/app/portfolio"],
  ["Network","/app/network"],["Protocol","/app/protocol"],["Top100","/app/top100"],["Nodes","/app/nodes"],
] as const;

export function LocaleSwitcher(){
  const {locale,setLocale}=useLocale(),t=useTranslations("common"); const [open,setOpen]=useState(false);
  const select=(value:"en-US"|"zh-CN")=>{setLocale(value);setOpen(false);};
  return <div className="locale"><button className="locale-trigger" aria-label={t("language")} aria-expanded={open} onClick={()=>setOpen(!open)}><Globe2 size={17}/><span className="locale-label">{locale==="zh-CN"?"中文":"EN"}</span><ChevronDown className="locale-chevron" size={13}/></button>{open&&<><button className="locale-backdrop" aria-label={t("cancel")} onClick={()=>setOpen(false)}/><div className="locale-menu" role="menu"><p>{t("language")}</p>{(["en-US","zh-CN"] as const).map(value=><button key={value} role="menuitemradio" aria-checked={locale===value} className={locale===value?"active":""} onClick={()=>select(value)}>{value==="en-US"?"English":"简体中文"}{locale===value&&" ✓"}</button>)}<button className="locale-cancel" onClick={()=>setOpen(false)}>{t("cancel")}</button></div></>}</div>;
}

export function WalletButton(){
  const {address,connect,disconnect,connectors,error,state}=useWallet(); const t=useTranslations("common"); const [open,setOpen]=useState(false);
  const copy=()=>address&&navigator.clipboard.writeText(address);
  if(!address)return <><button className="wallet" onClick={()=>setOpen(true)} disabled={state==="connecting"}><Wallet size={16}/>{state==="connecting"?t("connecting"):t("connect")}</button>{open&&<><button className="wallet-backdrop" aria-label={t("cancel")} onClick={()=>setOpen(false)}/><section className="wallet-menu wallet-connect"><header><b>{t("connectWallet")}</b><button onClick={()=>setOpen(false)} aria-label={t("cancel")}><X size={16}/></button></header>{connectors.map(connector=><button key={connector.id} onClick={()=>{void connect(connector.id);setOpen(false);}}>{connector.name}</button>)}{error&&<small>{error}</small>}</section></>}</>;
  return <div className="wallet-wrap"><button className="wallet" onClick={()=>setOpen(!open)}>{address.slice(0,6)}…{address.slice(-4)}<ChevronDown size={14}/></button>{open&&<section className="wallet-menu"><p>{address}</p><button onClick={copy}><Copy size={14}/>{t("copyAddress")}</button><a href={`https://testnet.bscscan.com/address/${address}`} target="_blank" rel="noreferrer">{t("viewBscScan")}</a><span><Network size={14}/>{t("testnet")}</span><button onClick={()=>{disconnect();setOpen(false);}}>{t("disconnect")}</button></section>}</div>;
}

export function AppShell({children,title}:{children:React.ReactNode;title:string}){
  const path=usePathname(),t=useTranslations("nav"); const [more,setMore]=useState(false);
  const breadcrumb=({Explore:"explore",Launch:"launch",Portfolio:"portfolio",Network:"network",Protocol:"protocol",Top100:"top100",Nodes:"nodes"} as Record<string,string>)[title];
  return <main className="product-shell"><aside className="app-sidebar"><Link className="app-brand" href="/"><span>A</span><b>ALP</b></Link><nav>{navigation.map(([label,href])=><Link key={href} href={href} className={path===href?"active":""}>{t(label.toLowerCase())}</Link>)}</nav></aside><section className="app-main"><header className="app-topbar"><div className="breadcrumb"><Link href="/app/explore">ALP</Link><span>/</span><b>{breadcrumb?t(breadcrumb):title}</b></div><div className="top-actions"><LocaleSwitcher/><span className="network"><i/>BSC Testnet</span><WalletButton/></div></header><div className="app-content">{children}</div></section><nav className="mobile-nav app-mobile-nav"><Link href="/app/explore">{t("explore")}</Link><Link href="/app/launch/relique">{t("launch")}</Link><Link href="/app/portfolio">{t("portfolio")}</Link><Link href="/app/network">{t("network")}</Link><button onClick={()=>setMore(!more)}><Menu size={18}/>{t("more")}</button>{more&&<div className="more-menu">{navigation.slice(4).map(([label,href])=><Link key={href} href={href}>{t(label.toLowerCase())}</Link>)}<LocaleSwitcher/></div>}</nav></main>;
}
