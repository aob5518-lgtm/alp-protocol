"use client";

import Link from "next/link";
import {AppShell, WalletButton} from "../components/app-shell";
import {EmptyState, Metric, ProductHeader, StatusBadge} from "../components/ui";
import {useTranslations, useWallet} from "../providers";
import {AssetNetwork} from "../components/asset-network";

const pending=<StatusBadge state="TESTNET_PENDING"/>;
export function ExplorePage(){
  const t=useTranslations("explore");
  return <AppShell titleKey="explore">
    <section className="explore-hero"><div><p>{t("eyebrow")}</p><h1>{t("title")}</h1><span>{t("subtitle")}</span><div><Link className="primary" href="/app/assets/relique">{t("primaryCTA")}</Link><Link className="secondary" href="/app/launch/relique">{t("secondaryCTA")}</Link></div></div><AssetNetwork/></section>
    <section className="product-metrics">{["assets","liquidity","burned","compute"].map(key=><Metric key={key} label={t(key)} state="TESTNET_PENDING"/>)}</section>
    <section className="product-section"><header><p>{t("directoryEyebrow")}</p><h2>{t("directoryTitle")}</h2></header><Link href="/app/assets/relique" className="asset-card"><b>RELIQUE</b><span>{t("reliqueSubtitle")}</span><small>{t("assetMeta")}</small>{pending}</Link></section>
  </AppShell>;
}
export function LaunchPage(){
  const t=useTranslations("launch");
  return <AppShell titleKey="launch"><ProductHeader eyebrow={t("eyebrow")} title={t("title")} subtitle={t("subtitle")}/>
    <div className="product-grid"><section className="panel"><h3>{t("participation")}</h3><label>{t("value")}<input value="" placeholder="0.00" readOnly/></label><p>{t("partnerValue")}</p><p>{t("usdt")}</p><p>{t("oracle")} —</p>{pending}</section>
    <section className="panel"><h3>{t("allocation")}</h3><div className="allocation-list">{[["50%","partner"],["25%","reward"],["25%","liquidity"]].map(([value,key])=><b key={key}>{value}<span>{t(key)}</span></b>)}</div><p>{t("time")}</p><small>{t("timeDetail")} {t("timeNotice")}</small></section></div>
    <section className="panel transaction-pending"><b>{t("pending")}</b><p>{t("pendingDetail")}</p>{["approveAsset","approveUsdt","submit"].map(key=><button key={key} disabled>{t(key)}</button>)}</section>
  </AppShell>;
}
export function PortfolioPage(){
  const t=useTranslations("portfolio"),{address}=useWallet();
  return <AppShell titleKey="portfolio"><ProductHeader eyebrow={t("eyebrow")} title={t("title")} subtitle={t("subtitle")}/>
    {!address?<EmptyState title={t("connectTitle")} detail={t("connectDetail")} action={<WalletButton/>}/>:<>
      <section className="product-metrics portfolio-metrics">{["balance","positions","compute","claimable","rewards"].map(key=><Metric key={key} label={t(key)} state="TESTNET_PENDING"/>)}</section>
      <EmptyState title={t("pendingTitle")} detail={t("pendingDetail",{address:address.slice(0,6)+"…"+address.slice(-4)})} action={<Link className="primary" href="/app/launch/relique">{t("cta")}</Link>}/>
    </>}
  </AppShell>;
}
export function NetworkPage(){
  const t=useTranslations("network");
  return <AppShell titleKey="network"><ProductHeader eyebrow={t("eyebrow")} title={t("title")} subtitle={t("subtitle")}/>
    <section className="network-rules">{[["depth","unlimited"],["referral","levels"],["differential","levels"]].map(([key,value])=><span key={key}>{t(key)}: <b>{t(value)}</b></span>)}</section>
    <section className="mechanism-grid">{["performance","district","tier"].map(key=><article key={key}><b>{t(key)}</b><span>{t(key+"Detail")}</span></article>)}</section>
    <EmptyState title={t("pending")} detail={t("detail")} action={pending}/>
  </AppShell>;
}
export function ProtocolPage(){
  const t=useTranslations("protocol");
  return <AppShell titleKey="protocol"><ProductHeader eyebrow={t("eyebrow")} title={t("title")} subtitle={t("subtitle")}/>
    <section className="product-metrics">{["supply","circulating","burned","reserve","pairAlp","pairUsdt","liquidity","compute","epoch","emission","burn","fee","lock"].map(key=><Metric key={key} label={t(key)} state="TESTNET_PENDING"/>)}</section>
    <section className="product-grid"><section className="panel"><h3>{t("flow")}</h3>{["flowPartner","flowUsdt","flowReserve","flowSell"].map(key=><p key={key}>{t(key)}</p>)}</section>
    <section className="panel"><h3>{t("contracts")}</h3><p>{t("pending")}</p>{["alpToken","mainPair","reserve","manager","engine","oracle","pool","cardToken"].map(key=><p key={key}>{t(key)} <span>—</span></p>)}</section></section>
  </AppShell>;
}
export function SimplePage(){
  const t=useTranslations("common");
  return <AppShell titleKey="position"><ProductHeader eyebrow="ALP" title={t("positionTitle")} subtitle={t("pendingDetail")}/><EmptyState title={t("pendingTitle")} detail={t("pendingDetail")}/></AppShell>;
}
export function ReliquePage(){
  const t=useTranslations("assetRelique"),c=useTranslations("common");
  return <AppShell titleKey="relique"><ProductHeader eyebrow={t("eyebrow")} title={t("title")} subtitle={t("subtitle")}/>
    <section className="detail-tabs">{["overview","launchPool","assetData","analytics","contracts","documents","risk"].map(key=><span key={key}>{t(key)}</span>)}</section>
    <section className="product-grid"><section className="panel"><h3>{t("panelTitle")}</h3><p>{t("intro")}</p><p>{t("detail")}</p>{pending}</section>
    <section className="panel"><h3>{t("assetData")}</h3><p>{c("token")}: CARD</p><p>{c("category")}: {c("collectibles")}</p><p>{t("metrics")}: {pending}</p></section></section>
    <div className="actions"><Link className="primary" href="/app/launch/relique">{t("participate")}</Link><Link className="secondary" href="/app/protocol">{t("viewContracts")}</Link></div>
  </AppShell>;
}
export function Top100Page(){
  const t=useTranslations("top100");
  return <AppShell titleKey="top100"><ProductHeader eyebrow="TOP100" title={t("title")} subtitle={t("subtitle")}/>
    <section className="mechanism-grid">{[["basis","compute"],["allocation","allocationDetail"],["source","snapshot"]].map(([key,value])=><article key={key}><b>{t(key)}</b><span>{t(value)}</span></article>)}</section>
    <section className="panel"><h3>{t("ranking")}</h3><div className="data-table">{["rank","wallet","compute","weight","reward","status"].map(key=><span key={key}>{t(key)}</span>)}</div><EmptyState title={t("pending")} detail={t("detail")}/></section>
  </AppShell>;
}
export function NodesPage(){
  const t=useTranslations("nodes");
  return <AppShell titleKey="nodes"><ProductHeader eyebrow="ALP" title={t("title")} subtitle={t("subtitle")}/>
    <section className="panel"><div className="data-table">{["node","type","region","status","weight","reward"].map(key=><span key={key}>{t(key)}</span>)}</div><EmptyState title={t("pending")} detail={t("detail")}/></section>
  </AppShell>;
}
