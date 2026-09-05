"use client";
import Link from "next/link";
import {LocaleSwitcher} from "../components/app-shell";
import {AssetNetwork} from "../components/asset-network";
import {useTranslations} from "../providers";

const sections=["assets","protocol","ecosystem","developers","docs"] as const;
const repository="https://github.com/aob5518-lgtm/alp-protocol";
export default function LandingClient(){
  const t=useTranslations("landing"),e=useTranslations("explore"),c=useTranslations("common");
  return <main className="landing">
    <header><Link href="/" className="app-brand"><span>A</span><b>ALP</b></Link><nav>{sections.map(key=><a key={key} href={"#"+key}>{t(key)}</a>)}</nav><div className="top-actions"><LocaleSwitcher/><Link className="primary" href="/app/explore">{t("launchApp")}</Link></div></header>
    <section className="landing-hero"><div><p>{e("eyebrow")}</p><h1>{e("title")}</h1><span>{e("subtitle")}</span><div className="actions"><Link className="primary" href="/app/assets/relique">{e("primaryCTA")}</Link><Link className="secondary" href="/app/launch/relique">{e("secondaryCTA")}</Link></div></div><AssetNetwork/></section>
    <div className="landing-body">
      <section id="assets" className="landing-section"><p className="eyebrow">{t("assets")}</p><h2>{t("assetsTitle")}</h2><div className="landing-cards"><article className="genesis-card"><span className="status-badge">{t("genesis")}</span><h3>RELIQUE</h3><p>{c("collectibles")}</p><p>{c("token")}: CARD</p><Link href="/app/assets/relique">{t("exploreRelique")} →</Link></article><article><h3>{t("standard")}</h3><p>{t("standardDetail")}</p></article><article><h3>{t("verifiable")}</h3><p>{t("verifiableDetail")}</p></article></div><p>{t("future")}</p><div className="future-assets">{["RWA","AI",c("gaming"),"IP"].map(label=><article key={label}><b>{label}</b><span>{t("upcoming")}</span></article>)}</div></section>
      <section id="protocol" className="landing-section"><p className="eyebrow">{t("protocol")}</p><h2>{t("protocolTitle")}</h2><ol className="protocol-flow">{[t("partner")+" + USDT",t("pool"),t("liquidityCompute"),t("emission"),t("globalNetwork")].map(label=><li key={label}>{label}</li>)}</ol><div className="capabilities">{["adapter","pool","computeEngine","risk"].map(key=><span key={key}>{t(key)}</span>)}</div></section>
      <section id="ecosystem" className="landing-section"><p className="eyebrow">{t("ecosystem")}</p><h2>{t("globalNetwork")}</h2><div className="landing-cards four">{["projects","nodes","participants","developers"].map(key=><article key={key}><h3>{t(key)}</h3><p>{t(key+"Detail")}</p></article>)}</div></section>
      <section id="developers" className="landing-section"><p className="eyebrow">{t("developers")}</p><h2>{t("build")}</h2><div className="landing-cards">{[["smartContracts","docs/CONTRACTS.md"],["sdk","docs/API.md"],["integration","docs/ARCHITECTURE.md"]].map(([key,path])=><article key={key}><h3>{t(key)}</h3><p className="status-badge">{t("development")}</p><a href={repository+"/blob/main/"+path} target="_blank" rel="noreferrer">{t("documentation")} →</a></article>)}</div></section>
      <section id="docs" className="landing-section"><p className="eyebrow">{t("docs")}</p><h2>{t("documentation")}</h2><div className="documentation-links">{[["architecture","ARCHITECTURE"],["economics","ECONOMIC_MODEL"],["smartContracts","CONTRACTS"],["security","SECURITY"],["deployment","DEPLOYMENT"]].map(([key,file])=><a key={key} href={repository+"/blob/main/docs/"+file+".md"} target="_blank" rel="noreferrer">{t(key)} ↗</a>)}</div></section>
      <section className="landing-section final-cta"><h2>{t("finalTitle")}</h2><div className="actions"><Link className="primary" href="/app/explore">{t("launchApp")}</Link><Link className="secondary" href="/app/assets/relique">{t("exploreRelique")}</Link></div></section>
    </div>
  </main>;
}
