"use client";
import {useTranslations} from "../providers";
export type DataStatus="TESTNET_PENDING"|"INDEXER_PENDING"|"INDEXER_SYNCING"|"DISCONNECTED"|"EMPTY"|"READY"|"WRONG_NETWORK"|"RPC_ERROR"|"ORACLE_STALE"|"PAUSED"|"CONNECTING";
export function StatusBadge({state}:{state:DataStatus}){const t=useTranslations("status");return <span className={`status-badge status-${state.toLowerCase()}`}>{t(state)}</span>}
export function Metric({label,value="—",state}:{label:string;value?:string;state?:DataStatus}){return <article className="product-metric"><span>{label}</span><strong>{value}</strong>{state&&<StatusBadge state={state}/>}</article>}
export function ProductHeader({eyebrow,title,subtitle}:{eyebrow:string;title:string;subtitle?:string}){return <header className="product-header"><p>{eyebrow}</p><h1>{title}</h1>{subtitle&&<span>{subtitle}</span>}</header>}
export function EmptyState({title,detail,action}:{title:string;detail:string;action?:React.ReactNode}){return <section className="empty-state"><h3>{title}</h3><p>{detail}</p>{action}</section>}
