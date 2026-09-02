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

const navigation: { name: View; icon: typeof Grid2X2; hint: string }[] = [
  { name: "Explore", icon: Grid2X2, hint: "Connected assets" },
  { name: "Launch", icon: Plus, hint: "Create position" },
  { name: "Portfolio", icon: Wallet, hint: "Your onchain activity" },
  { name: "Network", icon: Network, hint: "ALP Network" },
  { name: "ALP", icon: CircleGauge, hint: "Protocol transparency" },
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
  const [walletNotice, setWalletNotice] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [positionValue, setPositionValue] = useState("1000");
  const value = Math.max(0, Number(positionValue.replace(/[^0-9.]/g, "")) || 0);
  const allocation = useMemo(() => ({ partner: value / 2, usdt: value / 2, reward: value / 4, liquidity: value / 4 }), [value]);

  const selectView = (next: View) => {
    setView(next);
    setMenuOpen(false);
  };

  return (
    <main className="shell">
      <div className="ambient ambient-one" />
      <div className="ambient ambient-two" />
      <header className="topbar">
        <button className="brand" onClick={() => selectView("Explore")} aria-label="Open ALP Explore">
          <span className="brand-mark"><span /> <span /> <span /></span>
          <span>ALP</span>
          <em>ASSET LAUNCH PROTOCOL</em>
        </button>
        <nav className="desktop-nav" aria-label="Primary navigation">
          {navigation.map(({ name }) => (
            <button className={view === name ? "active" : ""} key={name} onClick={() => selectView(name)}>{name}</button>
          ))}
        </nav>
        <div className="top-actions">
          <button className="ghost-control"><Globe2 size={15} /> EN <ChevronDown size={14} /></button>
          <button className="ghost-control network-control"><span className="test-dot" /> BSC Testnet <ChevronDown size={14} /></button>
          <button className="wallet-button" onClick={() => setWalletNotice(true)}><Wallet size={16} /> Connect wallet</button>
          <button className="mobile-menu" onClick={() => setMenuOpen(!menuOpen)} aria-label="Open navigation">{menuOpen ? <X /> : <Menu />}</button>
        </div>
      </header>

      {menuOpen && <div className="mobile-drawer">{navigation.map(({ name, icon: Icon, hint }) => <button key={name} onClick={() => selectView(name)}><Icon size={18} /><span><strong>{name}</strong><small>{hint}</small></span></button>)}</div>}

      <div className="workspace">
        <aside className="rail">
          <div className="rail-label">PROTOCOL</div>
          {navigation.map(({ name, icon: Icon, hint }) => (
            <button key={name} className={view === name ? "rail-item active" : "rail-item"} onClick={() => selectView(name)}>
              <Icon size={18} /><span>{name}</span><small>{hint}</small>
            </button>
          ))}
          <div className="rail-bottom">
            <span className="live-dot" /> TESTNET PREVIEW
            <p>Onchain values load after wallet connection.</p>
          </div>
        </aside>

        <section className="content">
          {view === "Explore" && <Explore onLaunch={() => selectView("Launch")} />}
          {view === "Launch" && <Launch value={positionValue} setValue={setPositionValue} allocation={allocation} />}
          {view === "Portfolio" && <Portfolio />}
          {view === "Network" && <NetworkView />}
          {view === "ALP" && <ProtocolView />}
        </section>
      </div>

      <nav className="bottom-nav" aria-label="Mobile navigation">
        {navigation.map(({ name, icon: Icon }) => <button key={name} className={view === name ? "active" : ""} onClick={() => selectView(name)}><Icon size={18} /><span>{name}</span></button>)}
      </nav>

      {walletNotice && <div className="modal-backdrop" role="dialog" aria-modal="true" aria-label="Wallet connection notice"><div className="wallet-modal"><button onClick={() => setWalletNotice(false)} aria-label="Close"><X size={18} /></button><div className="modal-symbol"><Wallet size={22} /></div><SectionLabel>WALLET CONNECTION</SectionLabel><h2>Ready for the BSC testnet.</h2><p>WalletConnect, MetaMask, TokenPocket and OKX Wallet will be connected after the deployment address book is generated.</p><div className="modal-status"><span /> Contract address book pending</div></div></div>}
    </main>
  );
}

function Explore({ onLaunch }: { onLaunch: () => void }) {
  return <>
    <section className="hero">
      <div className="hero-copy"><SectionLabel>THE UNIVERSAL ASSET LAUNCH PROTOCOL</SectionLabel><h1>The infrastructure for launching <i>global assets</i> onchain.</h1><p>Connect assets. Activate liquidity. Build global markets.</p><div className="hero-actions"><button className="primary" onClick={onLaunch}>Launch a position <ArrowUpRight size={16} /></button><button className="secondary">Explore protocol <LineChart size={16} /></button></div></div>
      <div className="hero-orbit"><div className="orbit-core"><span>ALP</span><small>GLOBAL COMPUTE</small></div><div className="orb o1">RWA</div><div className="orb o2">AI</div><div className="orb o3">IP</div><div className="orbit-line" /></div>
    </section>
    <section className="metrics-row"><Metric label="Assets connected" value="—" detail="Awaiting registry sync" /><Metric label="Protocol liquidity" value="—" detail="Onchain verified" /><Metric label="ALP burned" value="—" detail="Epoch settlement" /><Metric label="Global compute" value="—" detail="Position-weighted" /></section>
    <section className="section-head"><div><SectionLabel>EXPLORE ASSETS</SectionLabel><h2>Asset launch <i>directory</i></h2></div><div className="filters"><button className="selected">All</button><button>RWA</button><button>AI</button><button>Gaming</button><button>IP</button></div></section>
    <section className="asset-grid"><article className="asset-card featured"><div className="asset-top"><div className="asset-symbol card-symbol">C</div><span className="status live">LIVE</span></div><div><h3>CARD</h3><p>Genesis Collectible Asset</p></div><div className="asset-rule" /><div className="asset-detail"><span>Category</span><b>Collectibles / RWA</b><span>Price</span><b>Oracle guarded</b><span>Launch pool</span><b>Available on testnet</b></div><button onClick={onLaunch}>View launch pool <ArrowUpRight size={15} /></button></article>
      {["GPU", "GOLD", "GAME"].map((asset, index) => <article className="asset-card muted" key={asset}><div className="asset-top"><div className={`asset-symbol shade-${index}`}>{asset.slice(0, 1)}</div><span className="status">UPCOMING</span></div><div><h3>{asset}</h3><p>Future asset vertical</p></div><div className="asset-rule" /><div className="asset-detail"><span>Registry state</span><b>Not connected</b><span>Launch status</span><b>Governance review</b></div><button disabled>Explore asset <ArrowUpRight size={15} /></button></article>)}</section>
  </>;
}

function Launch({ value, setValue, allocation }: { value: string; setValue: (next: string) => void; allocation: Record<string, number> }) {
  const format = (number: number) => new Intl.NumberFormat("en-US", { maximumFractionDigits: 2 }).format(number);
  return <><section className="page-heading"><SectionLabel>CREATE POSITION</SectionLabel><h1>Launch into <i>CARD</i></h1><p>Every position is constructed 50% partner asset and 50% USDT, then settled by verified onchain contracts.</p></section><div className="launch-layout"><section className="launch-form panel"><div className="panel-top"><span>01</span><div><h3>Position value</h3><p>Enter the USD value you want to allocate.</p></div></div><label className="currency-input"><span>USDT</span><input value={value} inputMode="decimal" onChange={(event) => setValue(event.target.value)} aria-label="Total position value" /><b>USD</b></label><div className="split-line"><span>Partner asset</span><strong>${format(allocation.partner)}</strong><i>50%</i></div><div className="split-line"><span>USDT contribution</span><strong>${format(allocation.usdt)}</strong><i>50%</i></div><div className="oracle-notice"><ShieldCheck size={18} /><span><b>Oracle required</b> Partner-token quantity is calculated from the configured onchain oracle at confirmation.</span></div><button className="primary wide">Connect wallet to continue <Wallet size={16} /></button></section><section className="allocation panel"><div className="panel-top"><span>02</span><div><h3>Protocol allocation</h3><p>Exact integer accounting occurs onchain.</p></div></div><div className="allocation-graphic"><div className="ring"><span>50 / 50</span></div><div className="allocation-legend"><p><i className="dot card" /> Partner Asset Vault <b>${format(allocation.partner)}</b></p><p><i className="dot blue" /> Reward Treasury <b>${format(allocation.reward)}</b></p><p><i className="dot violet" /> Liquidity <b>${format(allocation.liquidity)}</b></p></div></div><div className="compute-box"><div><span>Estimated base compute</span><strong>{format(Number(value) || 0)}</strong></div><div><span>Time compensation</span><strong>Oracle / pool state required</strong></div><div><span>Estimated effective compute</span><strong>—</strong></div></div><p className="disclaimer">No guaranteed return. ALP rewards depend on epoch emission and global effective compute.</p></section></div></>;
}

function Portfolio() { return <><section className="page-heading compact"><SectionLabel>YOUR PORTFOLIO</SectionLabel><h1>Every position. <i>Fully accounted.</i></h1></section><section className="portfolio-grid"><div className="portfolio-main panel"><div className="panel-label"><span>WALLET REQUIRED</span><button><Copy size={14} /> Copy address</button></div><EmptyData title="Connect a wallet to load your portfolio" body="Positions, claimable ALP, global weight and liquidity cycles are read from chain and indexer data." icon={Wallet} /></div><div className="stat-stack"><Metric label="ALP balance" value="—" detail="Wallet balance" /><Metric label="Active positions" value="—" detail="Onchain positions" /><Metric label="Claimable ALP" value="—" detail="Global reward index" /></div></section><section className="table-panel panel"><div className="table-head"><div><SectionLabel>MY POSITIONS</SectionLabel><h3>Position ledger</h3></div><button className="secondary">Learn about rewards <ArrowUpRight size={14} /></button></div><div className="table-empty"><Coins size={20} /><span>No wallet connected</span><small>Position history will appear here after chain sync.</small></div></section></> }

function NetworkView() { return <><section className="page-heading compact"><SectionLabel>ALP NETWORK</SectionLabel><h1>Global coordination, <i>not a team page.</i></h1><p>Your sponsor graph and tier values are calculated from onchain positions.</p></section><section className="network-layout"><div className="network-map panel"><div className="table-head"><div><SectionLabel>NETWORK GRAPH</SectionLabel><h3>Three levels by default</h3></div><button className="icon-button"><Columns3 size={16} /></button></div><div className="graph-placeholder"><div className="graph-node root">YOU</div><span className="graph-link l1" /><span className="graph-link l2" /><span className="graph-link l3" /><div className="graph-node n1">—</div><div className="graph-node n2">—</div><div className="graph-node n3">—</div><p>Connect a wallet to reveal the onchain network graph.</p></div></div><div className="tier-card panel"><SectionLabel>NETWORK TIER</SectionLabel><h2>— <i>V1–V9</i></h2><div className="tier-progress"><span /><i /></div><div className="tier-meta"><p>Small district <b>—</b></p><p>Next tier <b>Wallet required</b></p><p>Differential reward <b>—</b></p></div></div></section></> }

function ProtocolView() { return <><section className="page-heading compact"><SectionLabel>PROTOCOL TRANSPARENCY</SectionLabel><h1>Designed to be <i>auditable.</i></h1><p>Balances, emissions, burns and treasury flows are derived from events and verified contract state.</p></section><section className="protocol-grid"><div className="flow-card panel"><div className="table-head"><div><SectionLabel>TOKEN FLOW</SectionLabel><h3>ALP / USDT settlement</h3></div><button className="ghost-control">24H <ChevronDown size={14} /></button></div><div className="flow-lines"><div><span>Position USDT</span><i /><b>Reward Treasury</b></div><div><span>Position USDT</span><i /><b>Liquidity</b></div><div><span>Pair reserve</span><i /><b>Emission + Burn</b></div><div><span>Sell fee</span><i /><b>Five audited treasuries</b></div></div><p className="data-note"><span /> Testnet address book not loaded</p></div><div className="transparency-list panel"><SectionLabel>CONTRACT STATUS</SectionLabel>{[["Supply cap", "210,000,000 ALP"], ["Mint authority", "None"], ["Main Pair", "Awaiting deployment"], ["LP lock", "Awaiting deployment"], ["Production safety", "Not production ready"]].map(([label, state]) => <div key={label}><span>{label}</span><b>{state}</b></div>)}</div></section></> }
