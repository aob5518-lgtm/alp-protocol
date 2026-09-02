"use client";

import { useMemo, useState } from "react";
import {
  ArrowUpRight,
  ChevronDown,
  CircleDollarSign,
  CircleGauge,
  Coins,
  Columns3,
  Copy,
  Globe2,
  Grid2X2,
  Layers3,
  LineChart,
  Menu,
  Network,
  Plus,
  ShieldCheck,
  Sparkles,
  Wallet,
  X,
} from "lucide-react";

type View = "Explore" | "Launch" | "Portfolio" | "Network" | "ALP";
type Language = "en" | "zh";
type Translate = (english: string, chinese: string) => string;

const navigation: { name: View; zh: string; icon: typeof Grid2X2; hint: string; hintZh: string }[] = [
  { name: "Explore", zh: "探索", icon: Grid2X2, hint: "Connected assets", hintZh: "已接入资产" },
  { name: "Launch", zh: "发起", icon: Plus, hint: "Create position", hintZh: "创建仓位" },
  { name: "Portfolio", zh: "资产", icon: Wallet, hint: "Your onchain activity", hintZh: "链上活动" },
  { name: "Network", zh: "网络", icon: Network, hint: "ALP Network", hintZh: "ALP 网络" },
  { name: "ALP", zh: "协议", icon: CircleGauge, hint: "Protocol transparency", hintZh: "协议透明度" },
];

function Metric({ label, value, detail }: { label: string; value: string; detail: string }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
      <small>{detail}</small>
    </div>
  );
}

function SectionLabel({ children }: { children: React.ReactNode }) {
  return <p className="eyebrow">{children}</p>;
}

function EmptyData({ title, body, icon: Icon }: { title: string; body: string; icon: typeof CircleGauge }) {
  return (
    <div className="empty-data">
      <span className="empty-icon"><Icon size={18} /></span>
      <div>
        <strong>{title}</strong>
        <p>{body}</p>
      </div>
    </div>
  );
}

export default function Home() {
  const [view, setView] = useState<View>("Explore");
  const [language, setLanguage] = useState<Language>("en");
  const [languageOpen, setLanguageOpen] = useState(false);
  const [walletNotice, setWalletNotice] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [positionValue, setPositionValue] = useState("1000");
  const value = Math.max(0, Number(positionValue.replace(/[^0-9.]/g, "")) || 0);
  const allocation = useMemo(() => ({ partner: value / 2, usdt: value / 2, reward: value / 4, liquidity: value / 4 }), [value]);
  const t: Translate = (english, chinese) => language === "zh" ? chinese : english;

  const selectView = (next: View) => {
    setView(next);
    setMenuOpen(false);
  };

  return (
    <main className="shell" lang={language === "zh" ? "zh-CN" : "en"}>
      <div className="ambient ambient-one" />
      <div className="ambient ambient-two" />
      <header className="topbar">
        <button className="brand" onClick={() => selectView("Explore")} aria-label="Open ALP Explore">
          <span className="brand-mark"><span /> <span /> <span /></span>
          <span>ALP</span>
          <em>ASSET LAUNCH PROTOCOL</em>
        </button>
        <nav className="desktop-nav" aria-label="Primary navigation">
          {navigation.map(({ name, zh }) => (
            <button className={view === name ? "active" : ""} key={name} onClick={() => selectView(name)}>{language === "zh" ? zh : name}</button>
          ))}
        </nav>
        <div className="top-actions">
          <div className="language-picker">
            <button className="ghost-control" onClick={() => setLanguageOpen(!languageOpen)} aria-expanded={languageOpen}><Globe2 size={15} /> {language === "zh" ? "中文" : "EN"} <ChevronDown size={14} /></button>
            {languageOpen && <div className="language-menu"><button className={language === "en" ? "selected" : ""} onClick={() => { setLanguage("en"); setLanguageOpen(false); }}>English</button><button className={language === "zh" ? "selected" : ""} onClick={() => { setLanguage("zh"); setLanguageOpen(false); }}>中文</button></div>}
          </div>
          <button className="ghost-control network-control"><span className="test-dot" /> {t("BSC Testnet", "BSC 测试网")} <ChevronDown size={14} /></button>
          <button className="wallet-button" onClick={() => setWalletNotice(true)}><Wallet size={16} /> {t("Connect wallet", "连接钱包")}</button>
          <button className="mobile-menu" onClick={() => setMenuOpen(!menuOpen)} aria-label="Open navigation">{menuOpen ? <X /> : <Menu />}</button>
        </div>
      </header>

      {menuOpen && <div className="mobile-drawer">{navigation.map(({ name, zh, icon: Icon, hint, hintZh }) => <button key={name} onClick={() => selectView(name)}><Icon size={18} /><span><strong>{language === "zh" ? zh : name}</strong><small>{language === "zh" ? hintZh : hint}</small></span></button>)}<button onClick={() => setLanguage(language === "en" ? "zh" : "en")}><Globe2 size={18} /><span><strong>{language === "zh" ? "English" : "中文"}</strong><small>{t("Switch language", "切换语言")}</small></span></button></div>}

      <div className="workspace">
        <aside className="rail">
          <div className="rail-label">PROTOCOL</div>
          {navigation.map(({ name, zh, icon: Icon, hint, hintZh }) => (
            <button key={name} className={view === name ? "rail-item active" : "rail-item"} onClick={() => selectView(name)}>
              <Icon size={18} /><span>{language === "zh" ? zh : name}</span><small>{language === "zh" ? hintZh : hint}</small>
            </button>
          ))}
          <div className="rail-bottom">
            <span className="live-dot" /> {t("TESTNET PREVIEW", "测试网预览")}
            <p>{t("Onchain values load after wallet connection.", "连接钱包后加载链上数据。")}</p>
          </div>
        </aside>

        <section className="content">
          {view === "Explore" && <Explore onLaunch={() => selectView("Launch")} t={t} />}
          {view === "Launch" && <Launch value={positionValue} setValue={setPositionValue} allocation={allocation} t={t} />}
          {view === "Portfolio" && <Portfolio t={t} />}
          {view === "Network" && <NetworkView t={t} />}
          {view === "ALP" && <ProtocolView t={t} />}
        </section>
      </div>

      <nav className="bottom-nav" aria-label="Mobile navigation">
        {navigation.map(({ name, zh, icon: Icon }) => <button key={name} className={view === name ? "active" : ""} onClick={() => selectView(name)}><Icon size={18} /><span>{language === "zh" ? zh : name}</span></button>)}
      </nav>

      {walletNotice && <div className="modal-backdrop" role="dialog" aria-modal="true" aria-label="Wallet connection notice"><div className="wallet-modal"><button onClick={() => setWalletNotice(false)} aria-label="Close"><X size={18} /></button><div className="modal-symbol"><Wallet size={22} /></div><SectionLabel>{t("WALLET CONNECTION", "钱包连接")}</SectionLabel><h2>{t("Ready for the BSC testnet.", "已准备接入 BSC 测试网。")}</h2><p>{t("WalletConnect, MetaMask, TokenPocket and OKX Wallet will be connected after the deployment address book is generated.", "部署地址簿生成后，将接入 WalletConnect、MetaMask、TokenPocket 和 OKX Wallet。")}</p><div className="modal-status"><span /> {t("Contract address book pending", "合约地址簿待生成")}</div></div></div>}
    </main>
  );
}

function Explore({ onLaunch, t }: { onLaunch: () => void; t: Translate }) {
  return <>
    <section className="hero">
      <div className="hero-copy"><SectionLabel>{t("THE UNIVERSAL ASSET LAUNCH PROTOCOL", "通用资产发行协议")}</SectionLabel><h1>{t("The infrastructure for launching ", "面向 ") }<i>{t("global assets", "全球资产")}</i>{t(" onchain.", " 的链上基础设施。")}</h1><p>{t("Connect assets. Activate liquidity. Build global markets.", "连接资产，激活流动性，构建全球化市场。")}</p><div className="hero-actions"><button className="primary" onClick={onLaunch}>{t("Launch a position", "发起仓位")} <ArrowUpRight size={16} /></button><button className="secondary">{t("Explore protocol", "探索协议")} <LineChart size={16} /></button></div></div>
      <div className="hero-orbit"><div className="orbit-core"><span>ALP</span><small>GLOBAL COMPUTE</small></div><div className="orb o1">RWA</div><div className="orb o2">AI</div><div className="orb o3">IP</div><div className="orbit-line" /></div>
    </section>
    <section className="metrics-row"><Metric label={t("Assets connected", "已接入资产")} value="—" detail={t("Awaiting registry sync", "等待注册表同步")} /><Metric label={t("Protocol liquidity", "协议流动性")} value="—" detail={t("Onchain verified", "链上验证")} /><Metric label={t("ALP burned", "已销毁 ALP")} value="—" detail={t("Epoch settlement", "周期结算")} /><Metric label={t("Global compute", "全球算力")} value="—" detail={t("Position-weighted", "仓位权重")} /></section>
    <section className="section-head"><div><SectionLabel>{t("EXPLORE ASSETS", "探索资产")}</SectionLabel><h2>{t("Asset launch ", "资产发行")}<i>{t("directory", "目录")}</i></h2></div><div className="filters"><button className="selected">{t("All", "全部")}</button><button>RWA</button><button>AI</button><button>{t("Gaming", "游戏")}</button><button>IP</button></div></section>
    <section className="asset-grid"><article className="asset-card featured"><div className="asset-top"><div className="asset-symbol card-symbol">C</div><span className="status live">{t("LIVE", "已上线")}</span></div><div><h3>CARD</h3><p>{t("Genesis Collectible Asset", "创世收藏品资产")}</p></div><div className="asset-rule" /><div className="asset-detail"><span>{t("Category", "类别")}</span><b>{t("Collectibles / RWA", "收藏品 / RWA")}</b><span>{t("Price", "价格")}</span><b>{t("Oracle guarded", "预言机保护")}</b><span>{t("Launch pool", "发行池")}</span><b>{t("Available on testnet", "测试网可用")}</b></div><button onClick={onLaunch}>{t("View launch pool", "查看发行池")} <ArrowUpRight size={15} /></button></article>
      {["GPU", "GOLD", "GAME"].map((asset, index) => <article className="asset-card muted" key={asset}><div className="asset-top"><div className={`asset-symbol shade-${index}`}>{asset.slice(0, 1)}</div><span className="status">{t("UPCOMING", "即将推出")}</span></div><div><h3>{asset}</h3><p>{t("Future asset vertical", "未来资产方向")}</p></div><div className="asset-rule" /><div className="asset-detail"><span>{t("Registry state", "注册状态")}</span><b>{t("Not connected", "尚未接入")}</b><span>{t("Launch status", "发行状态")}</span><b>{t("Governance review", "治理审核中")}</b></div><button disabled>{t("Explore asset", "探索资产")} <ArrowUpRight size={15} /></button></article>)}</section>
  </>;
}

function Launch({ value, setValue, allocation, t }: { value: string; setValue: (next: string) => void; allocation: Record<string, number>; t: Translate }) {
  const format = (number: number) => new Intl.NumberFormat("en-US", { maximumFractionDigits: 2 }).format(number);
  return <><section className="page-heading"><SectionLabel>{t("CREATE POSITION", "创建仓位")}</SectionLabel><h1>{t("Launch into ", "发行至 ")}<i>CARD</i></h1><p>{t("Every position is constructed 50% partner asset and 50% USDT, then settled by verified onchain contracts.", "每个仓位由 50% 合作资产与 50% USDT 构成，并由已验证的链上合约结算。")}</p></section><div className="launch-layout"><section className="launch-form panel"><div className="panel-top"><span>01</span><div><h3>{t("Position value", "仓位金额")}</h3><p>{t("Enter the USD value you want to allocate.", "输入希望配置的美元金额。")}</p></div></div><label className="currency-input"><span>USDT</span><input value={value} inputMode="decimal" onChange={(event) => setValue(event.target.value)} aria-label="Total position value" /><b>USD</b></label><div className="split-line"><span>{t("Partner asset", "合作资产")}</span><strong>${format(allocation.partner)}</strong><i>50%</i></div><div className="split-line"><span>{t("USDT contribution", "USDT 注入")}</span><strong>${format(allocation.usdt)}</strong><i>50%</i></div><div className="oracle-notice"><ShieldCheck size={18} /><span><b>{t("Oracle required", "需要预言机")}</b> {t("Partner-token quantity is calculated from the configured onchain oracle at confirmation.", "确认时将按配置的链上预言机计算合作代币数量。")}</span></div><button className="primary wide">{t("Connect wallet to continue", "连接钱包以继续")} <Wallet size={16} /></button></section><section className="allocation panel"><div className="panel-top"><span>02</span><div><h3>{t("Protocol allocation", "协议分配")}</h3><p>{t("Exact integer accounting occurs onchain.", "精确的整数记账在链上完成。")}</p></div></div><div className="allocation-graphic"><div className="ring"><span>50 / 50</span></div><div className="allocation-legend"><p><i className="dot card" /> {t("Partner Asset Vault", "合作资产金库")} <b>${format(allocation.partner)}</b></p><p><i className="dot blue" /> {t("Reward Treasury", "奖励金库")} <b>${format(allocation.reward)}</b></p><p><i className="dot violet" /> {t("Liquidity", "流动性")} <b>${format(allocation.liquidity)}</b></p></div></div><div className="compute-box"><div><span>{t("Estimated base compute", "预计基础算力")}</span><strong>{format(Number(value) || 0)}</strong></div><div><span>{t("Time compensation", "时间补偿")}</span><strong>{t("Oracle / pool state required", "需要预言机 / 池状态")}</strong></div><div><span>{t("Estimated effective compute", "预计有效算力")}</span><strong>—</strong></div></div><p className="disclaimer">{t("No guaranteed return. ALP rewards depend on epoch emission and global effective compute.", "不承诺收益。ALP 奖励取决于周期发行与全球有效算力。")}</p></section></div></>;
}

function Portfolio({ t }: { t: Translate }) { return <><section className="page-heading compact"><SectionLabel>{t("YOUR PORTFOLIO", "我的资产")}</SectionLabel><h1>{t("Every position. ", "每一笔仓位，")}<i>{t("Fully accounted.", "完整记账。")}</i></h1></section><section className="portfolio-grid"><div className="portfolio-main panel"><div className="panel-label"><span>{t("WALLET REQUIRED", "需要钱包")}</span><button><Copy size={14} /> {t("Copy address", "复制地址")}</button></div><EmptyData title={t("Connect a wallet to load your portfolio", "连接钱包以加载资产")} body={t("Positions, claimable ALP, global weight and liquidity cycles are read from chain and indexer data.", "仓位、可领取 ALP、全球权重与流动性周期均读取自链上与索引数据。")} icon={Wallet} /></div><div className="stat-stack"><Metric label={t("ALP balance", "ALP 余额")} value="—" detail={t("Wallet balance", "钱包余额")} /><Metric label={t("Active positions", "活跃仓位")} value="—" detail={t("Onchain positions", "链上仓位")} /><Metric label={t("Claimable ALP", "可领取 ALP")} value="—" detail={t("Global reward index", "全球奖励指数")} /></div></section><section className="table-panel panel"><div className="table-head"><div><SectionLabel>{t("MY POSITIONS", "我的仓位")}</SectionLabel><h3>{t("Position ledger", "仓位账本")}</h3></div><button className="secondary">{t("Learn about rewards", "了解奖励")} <ArrowUpRight size={14} /></button></div><div className="table-empty"><Coins size={20} /><span>{t("No wallet connected", "未连接钱包")}</span><small>{t("Position history will appear here after chain sync.", "链上同步后将在此显示仓位历史。")}</small></div></section></> }

function NetworkView({ t }: { t: Translate }) { return <><section className="page-heading compact"><SectionLabel>{t("ALP NETWORK", "ALP 网络")}</SectionLabel><h1>{t("Global coordination, ", "全球协作，")}<i>{t("not a team page.", "不止是团队页面。")}</i></h1><p>{t("Your sponsor graph and tier values are calculated from onchain positions.", "推荐网络与等级数值均由链上仓位计算。")}</p></section><section className="network-layout"><div className="network-map panel"><div className="table-head"><div><SectionLabel>{t("NETWORK GRAPH", "网络关系图")}</SectionLabel><h3>{t("Three levels by default", "默认展示三层")}</h3></div><button className="icon-button"><Columns3 size={16} /></button></div><div className="graph-placeholder"><div className="graph-node root">{t("YOU", "你")}</div><span className="graph-link l1" /><span className="graph-link l2" /><span className="graph-link l3" /><div className="graph-node n1">—</div><div className="graph-node n2">—</div><div className="graph-node n3">—</div><p>{t("Connect a wallet to reveal the onchain network graph.", "连接钱包以查看链上网络关系图。")}</p></div></div><div className="tier-card panel"><SectionLabel>{t("NETWORK TIER", "网络等级")}</SectionLabel><h2>— <i>V1–V9</i></h2><div className="tier-progress"><span /><i /></div><div className="tier-meta"><p>{t("Small district", "小区")} <b>—</b></p><p>{t("Next tier", "下一等级")} <b>{t("Wallet required", "需要钱包")}</b></p><p>{t("Differential reward", "级差奖励")} <b>—</b></p></div></div></section></> }

function ProtocolView({ t }: { t: Translate }) { return <><section className="page-heading compact"><SectionLabel>{t("PROTOCOL TRANSPARENCY", "协议透明度")}</SectionLabel><h1>{t("Designed to be ", "为")}<i>{t("auditable.", "可审计而生。")}</i></h1><p>{t("Balances, emissions, burns and treasury flows are derived from events and verified contract state.", "余额、发行、销毁与金库流向均来自事件和经验证的合约状态。")}</p></section><section className="protocol-grid"><div className="flow-card panel"><div className="table-head"><div><SectionLabel>{t("TOKEN FLOW", "代币流向")}</SectionLabel><h3>ALP / USDT {t("settlement", "结算")}</h3></div><button className="ghost-control">24H <ChevronDown size={14} /></button></div><div className="flow-lines"><div><span>{t("Position USDT", "仓位 USDT")}</span><i /><b>{t("Reward Treasury", "奖励金库")}</b></div><div><span>{t("Position USDT", "仓位 USDT")}</span><i /><b>{t("Liquidity", "流动性")}</b></div><div><span>{t("Pair reserve", "交易对储备")}</span><i /><b>{t("Emission + Burn", "发行 + 销毁")}</b></div><div><span>{t("Sell fee", "卖出手续费")}</span><i /><b>{t("Five audited treasuries", "五个审计金库")}</b></div></div><p className="data-note"><span /> {t("Testnet address book not loaded", "测试网地址簿未加载")}</p></div><div className="transparency-list panel"><SectionLabel>{t("CONTRACT STATUS", "合约状态")}</SectionLabel>{[[t("Supply cap", "供应上限"), "210,000,000 ALP"], [t("Mint authority", "铸币权限"), t("None", "无")], [t("Main Pair", "主交易对"), t("Awaiting deployment", "等待部署")], [t("LP lock", "LP 锁定"), t("Awaiting deployment", "等待部署")], [t("Production safety", "生产安全"), t("Not production ready", "尚未达到生产就绪")]].map(([label, state]) => <div key={label}><span>{label}</span><b>{state}</b></div>)}</div></section></> }
