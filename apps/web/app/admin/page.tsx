"use client";
import {useEffect, useState} from "react";
import {Activity, BarChart3, Boxes, FileCheck2, Landmark, ListChecks, Network, Scale, ShieldAlert, ShieldCheck} from "lucide-react";
import {useTranslations, useWallet} from "../providers";
import {LocaleSwitcher, WalletButton} from "../components/app-shell";
import "./admin.css";
const sections=[["overview",Activity],["assets",Boxes],["pools",Landmark],["network",Network],["snapshots",BarChart3],["nodes",ShieldCheck],["top100",ListChecks],["oracles",Scale],["liquidity",Activity],["treasuries",Landmark],["risk",ShieldAlert],["reconciliation",FileCheck2],["proposals",ListChecks],["audit",FileCheck2]] as const;
export default function AdminPage(){
  const t=useTranslations("admin"),{address}=useWallet();
  const [selected,setSelected]=useState("overview"),[auditState,setAuditState]=useState("signIn");
  useEffect(()=>{if(!address){setAuditState("signIn");return;}void fetch("http://localhost:4000/v1/admin/audit").then(response=>setAuditState(response.status===403?"rbac":response.ok?"connected":"unavailable")).catch(()=>setAuditState("unavailable"));},[address]);
  return <main className="admin-shell"><aside className="admin-sidebar"><div className="admin-brand"><span>A</span><div><b>ALP</b><small>{t("eyebrow")}</small></div></div><p>{t("operations")}</p>{sections.map(([key,Icon])=><button key={key} className={selected===key?"selected":""} onClick={()=>setSelected(key)}><Icon size={16}/>{t(key)}</button>)}<div className="admin-testnet"><i/>{t("testnet")}</div></aside>
  <section className="admin-main"><header><div><p>{t("eyebrow")} / {t(selected)}</p><h1>{selected==="overview"?t("title"):t(selected)}</h1></div><div className="top-actions"><LocaleSwitcher/><WalletButton/></div></header><article className="admin-warning"><ShieldAlert size={18}/><div><b>{t("safe")}</b><span>{t("restricted")}</span></div></article>
  <section className="admin-kpis"><article><span>{t("deployment")}</span><strong>{t("pending")}</strong><small>{t("addressPending")}</small></article><article><span>{t("role")}</span><strong>{t(address?"verifying":"disconnected")}</strong><small>{t("auth")}</small></article><article><span>{t("source")}</span><strong>{t("events")}</strong><small>{t(auditState)}</small></article></section>
  <section className="admin-workspace"><article><p>{t("control")}</p><h2>{t(selected)}</h2><p>{t(selected==="snapshots"?"snapshotDetail":"detail")}</p><button className="secondary" disabled={!address}>{t("prepare")}</button></article><article><p>{t("auditStatus")}</p><h2>{t("chain")}</h2><p>{t(auditState)}</p><button className="secondary" disabled={!address}>{t("viewAudit")}</button></article></section></section></main>;
}
