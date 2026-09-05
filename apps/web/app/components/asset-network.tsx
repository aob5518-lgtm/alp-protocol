"use client";
import {useTranslations} from "../providers";
export function AssetNetwork(){
  const t=useTranslations("explore"),c=useTranslations("common");
  return <div className="asset-network" role="img" aria-label={t("networkLabel")}>
    <svg className="asset-connections" viewBox="0 0 290 290" aria-hidden="true"><path d="M145 145 L145 34" className="genesis-link"/><path d="M145 145 L275 100 M145 145 L240 230 M145 145 L120 264 M145 145 L10 105"/></svg>
    <b>ALP</b>{["RELIQUE","RWA","AI",c("gaming"),"IP"].map((label,index)=><span key={index} className={index===0?"genesis":""}>{label}</span>)}
  </div>;
}
