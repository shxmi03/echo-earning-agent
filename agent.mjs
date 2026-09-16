/**
 * Always-on earning agent — vrti se na GitHub Actions cronu (GitHubovi serveri, živi i kad je
 * kućno računalo ugašeno). Bez dependencyja: samo Node 20+ global fetch. Svaki run:
 *   1. čita on-chain balanse naših receive-only novčanika (prava zarada se pojavi tu)
 *   2. skenira Superteam agent oglase za nove/otvorene bountyje
 *   3. prati tvoje PR-ove (pay-per-merged-PR rail — merge znači da je račun ispostavljen)
 *   4. piše status.md + history.jsonl koje workflow commita
 *
 * Secrets (GitHub repo → Settings → Secrets): SUPERTEAM_API_KEY (opcionalno; bez njega se preskače skeniranje oglasa).
 * Nikakvi privatni ključevi ne žive ovdje — ovaj proces samo ČITA. Zarađivanje/trošenje ostaje offline.
 */
import { writeFileSync, appendFileSync, readFileSync, unlinkSync } from 'node:fs'

// ── Konfiguracija ────────────────────────────────────────────────────────────
// Samo JAVNE adrese. Prazno = ta provjera se preskače.
const SOL_WALLET = '35QuHq2nMFKZDtjndReQdA42XwR9UJ2fHEqwUDqDSv9G'
const EVM_WALLET = '' // npr. '0x...' za Base USDC; prazno dok nema Base novčanika
const GITHUB_LOGIN = 'shxmi03'
const SUPERTEAM_USERNAME = 'shxmi-apricot-62'
const BASE_USDC = '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'
const SOL_USDC_MINT = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'
const now = new Date().toISOString()

// ── Novčanici (samo čitanje javnih balansa) ──────────────────────────────────
async function baseUsdc() {
  if (!EVM_WALLET) return null
  try {
    const r = await fetch('https://mainnet.base.org', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0', id: 1, method: 'eth_call',
        params: [{ to: BASE_USDC, data: '0x70a08231000000000000000000000000' + EVM_WALLET.slice(2) }, 'latest'],
      }),
      signal: AbortSignal.timeout(15000),
    })
    const j = await r.json()
    return Number(BigInt(j.result || '0x0')) / 1e6
  } catch (e) { return `err:${e.message}` }
}

async function solUsdc() {
  try {
    const r = await fetch('https://api.mainnet-beta.solana.com', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0', id: 1, method: 'getTokenAccountsByOwner',
        params: [SOL_WALLET, { mint: SOL_USDC_MINT }, { encoding: 'jsonParsed' }],
      }),
      signal: AbortSignal.timeout(15000),
    })
    const j = await r.json()
    return (j?.result?.value ?? []).reduce((s, a) => s + (Number(a?.account?.data?.parsed?.info?.tokenAmount?.uiAmount) || 0), 0)
  } catch (e) { return `err:${e.message}` }
}

// Native SOL — ugig bountyji (npr. chovyjevi) plaćaju u NATIVNOM SOL-u, što token-account upit iznad ne vidi.
async function solNative() {
  try {
    const r = await fetch('https://api.mainnet-beta.solana.com', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'getBalance', params: [SOL_WALLET] }),
      signal: AbortSignal.timeout(15000),
    })
    const j = await r.json()
    return (j?.result?.value ?? 0) / 1e9
  } catch (e) { return `err:${e.message}` }
}

// ── Superteam agent oglasi ───────────────────────────────────────────────────
async function superteamLive() {
  const key = process.env.SUPERTEAM_API_KEY
  if (!key) return { skipped: 'nema SUPERTEAM_API_KEY secreta' }
  try {
    const r = await fetch('https://superteam.fun/api/agents/listings/live?take=50', {
      headers: { Authorization: `Bearer ${key}` },
      signal: AbortSignal.timeout(20000),
    })
    if (!r.ok) return { error: `HTTP ${r.status}` }
    const d = await r.json()
    const items = Array.isArray(d) ? d : d.result || []
    const open = items.filter((l) => (l.deadline || '9999') > now)
      // agentAccess je signal konkurencije: AGENT_ONLY oglasi su skriveni od ljudskih feedova, pa su
      // najbolji omjer (prošle AGENT_ONLY runde plaćale 3000–5000). Zato ide prvo + reward.
      .map((l) => ({ slug: l.slug, type: l.type, reward: l.rewardAmount, token: l.token, access: l.agentAccess, deadline: (l.deadline || '').slice(0, 10) }))
      .sort((a, b) => (b.access === 'AGENT_ONLY' ? 1 : 0) - (a.access === 'AGENT_ONLY' ? 1 : 0) || (b.reward || 0) - (a.reward || 0))
    return { total: items.length, open }
  } catch (e) { return { error: e.message } }
}

// ── GitHub PR watch (pay-per-merged-PR rail) ─────────────────────────────────
// Plaćanje je izvan platforme i ručno: plaća se NAKON mergea i nakon što se pošalje invoice.
// Zato moramo uhvatiti MERGE tranziciju, inače spojen PR ostane nezaračunat zauvijek.
async function githubPrs() {
  try {
    const q = encodeURIComponent(`author:${GITHUB_LOGIN} type:pr`)
    const headers = { Accept: 'application/vnd.github+json', 'User-Agent': 'earning-agent' }
    if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`
    const r = await fetch(`https://api.github.com/search/issues?q=${q}&sort=updated&order=desc&per_page=50`, { headers, signal: AbortSignal.timeout(15000) })
    if (!r.ok) return { error: `HTTP ${r.status}` }
    const d = await r.json()
    const prs = (d.items || []).map((p) => ({
      repo: (p.repository_url || '').split('/').pop(),
      num: p.number,
      title: (p.title || '').slice(0, 50),
      merged: Boolean(p.pull_request && p.pull_request.merged_at),
      state: p.state,
      url: p.html_url,
    }))
    return { total: prs.length, merged: prs.filter((p) => p.merged).length, prs }
  } catch (e) { return { error: e.message } }
}

// ── OpenTask rail ────────────────────────────────────────────────────────────
// Ima strojno čitljiv status po metodi; kad nešto prijeđe u "available", rail je ŽIV i može se
// djelovati (nudi x402-v2 koji naš tip servisa već govori). Drugi izvor zarade bez prijave.
async function openTaskRail() {
  try {
    const r = await fetch('https://opentask.ai/api/payment-methods', { signal: AbortSignal.timeout(10000) })
    if (!r.ok) return { state: `HTTP ${r.status}` }
    const d = await r.json()
    const methods = Array.isArray(d.methods) ? d.methods : []
    const live = methods.filter((m) => m.status === 'available')
    return { state: live.length ? 'AVAILABLE' : 'unconfigured', live: live.map((m) => m.protocol) }
  } catch (e) { return { state: `err:${e.message}` } }
}

const usdc = await baseUsdc()
const solUsdcBal = await solUsdc()
const solNativeBal = await solNative()
const superteam = await superteamLive()
const github = await githubPrs()
const openTask = await openTaskRail()

// ── Tranzicije ───────────────────────────────────────────────────────────────
// Promjena balansa vs. prethodni run — uplata je THE profit event, pa se mora javiti glasno, a ne
// ostati tiho promijenjen broj koji nitko ne čita.
let prevUsdc = null, prevSol = null, prevSolNative = null, prevMerged = 0
try {
  const lines = readFileSync(new URL('./history.jsonl', import.meta.url), 'utf8').trim().split('\n')
  if (lines.length) {
    const p = JSON.parse(lines[lines.length - 1])
    if (typeof p.baseUsdc === 'number') prevUsdc = p.baseUsdc
    if (typeof p.solUsdc === 'number') prevSol = p.solUsdc
    if (typeof p.solNative === 'number') prevSolNative = p.solNative
    prevMerged = p.github?.merged || 0
  }
} catch {}

const delta = (typeof usdc === 'number' && typeof prevUsdc === 'number') ? usdc - prevUsdc : 0
const solDelta = (typeof solUsdcBal === 'number' && typeof prevSol === 'number') ? solUsdcBal - prevSol : 0
const solNativeDelta = (typeof solNativeBal === 'number' && typeof prevSolNative === 'number') ? solNativeBal - prevSolNative : 0
// PR upravo spojen → bounty je sada fakturom naplativ; šalje se invoice. Fires once na porast.
const newMerge = (github.merged || 0) > prevMerged

// ── Novi oglasi ──────────────────────────────────────────────────────────────
let seen = []
try { seen = JSON.parse(readFileSync(new URL('./seen-listings.json', import.meta.url), 'utf8')) } catch {}
const openSlugs = (superteam.open || []).map((o) => o.slug)
const fresh = openSlugs.filter((s) => !seen.includes(s))
const freshDetail = (superteam.open || []).filter((o) => fresh.includes(o.slug))
writeFileSync(new URL('./seen-listings.json', import.meta.url), JSON.stringify([...new Set([...seen, ...openSlugs])], null, 0))

const snapshot = { ts: now, baseUsdc: usdc, solUsdc: solUsdcBal, solNative: solNativeBal, delta, solDelta, solNativeDelta, openTask, github, superteam, newListings: fresh }
appendFileSync(new URL('./history.jsonl', import.meta.url), JSON.stringify(snapshot) + '\n')

// ── status.md ────────────────────────────────────────────────────────────────
const md = `# Earning agent status

_Zadnji run: ${now} (UTC), na GitHub Actions._

## 💰 Novčanik (prava zarada sliježe ovdje)
- **Solana USDC** \`${SOL_WALLET}\`: **${solUsdcBal}**${solDelta > 0 ? ` · 🎉 **+${solDelta.toFixed(6)} primljeno od zadnjeg runa!**` : ''}
- **Solana (nativni SOL — dio bountyja plaća ovdje)**: **${solNativeBal}**${solNativeDelta > 0 ? ` · 🎉 **+${solNativeDelta.toFixed(9)} SOL primljeno od zadnjeg runa!**` : ''}
- ${EVM_WALLET ? `**Base USDC** \`${EVM_WALLET}\`: **${usdc}**${delta > 0 ? ` · 🎉 **+${delta.toFixed(6)} primljeno od zadnjeg runa!**` : ''}` : '_Base USDC: nije konfiguriran (dodaj adresu u `agent.mjs` → `EVM_WALLET`)_'}

## 🎯 Otvoreni agent oglasi (Superteam) — AGENT_ONLY prvo (najmanja konkurencija)
${superteam.skipped ? `_skeniranje preskočeno: ${superteam.skipped}_`
  : superteam.error ? `_greška skeniranja: ${superteam.error}_`
  : (superteam.open?.length
      ? superteam.open.map((o) => `- ${o.access === 'AGENT_ONLY' ? '🔒 **AGENT_ONLY**' : 'open'} · \`${o.slug}\` — ${o.type} · ${o.reward} ${o.token || ''} · rok ${o.deadline}`).join('\n')
      : '_trenutno nema otvorenih_')}

## 🔧 Tvoji PR-ovi (pay-per-merged-PR; nakon mergea treba poslati invoice)
- ${github.error ? `_err: ${github.error}_` : github.prs?.length ? `${github.merged}/${github.total} spojeno · ${github.prs.map((p) => `${p.merged ? '✅' : p.state === 'closed' ? '❌' : '⏳'} ${p.repo}#${p.num}`).join(', ')}${newMerge ? ' · 💵 **PR UPRAVO SPOJEN — POŠALJI INVOICE**' : ''}` : '_još nema PR-ova_'}

## 🔀 Alt rails
- **OpenTask** router: **${openTask.state}**${openTask.live?.length ? ` · LIVE metode: ${openTask.live.join(', ')} — ACT NOW` : ' _(čeka oživljavanje; govori x402-v2)_'}

## 🪪 Identitet agenta
- Superteam agent: \`${SUPERTEAM_USERNAME}\` · GitHub: \`${GITHUB_LOGIN}\`
- _Claim kod za Superteam zaradu drži se LOKALNO kod operatera, nikad u ovom repou._

${fresh.length ? `## 🆕 Novo od zadnjeg runa\n${freshDetail.map((o) => `- ${o.access === 'AGENT_ONLY' ? '🔒 AGENT_ONLY' : 'open'} · \`${o.slug}\` — ${o.reward} ${o.token || ''} · rok ${o.deadline}`).join('\n')}` : ''}

---
_Ovu datoteku prepisuje \`agent.mjs\` na svakom zakazanom runu. Povijest u \`history.jsonl\`._
`
writeFileSync(new URL('./status.md', import.meta.url), md)

// ── NOTIFY sentinel ──────────────────────────────────────────────────────────
// Prisutan SAMO na tranzicijskom runu. Zadnji korak workflowa ruši run kad postoji (→ GitHub
// maila vlasniku repoa), pa se obriše na sljedećem runu: jedan događaj = jedna obavijest.
const NOTIFY = new URL('./NOTIFY.txt', import.meta.url)
const notify = delta > 0 || solDelta > 0 || solNativeDelta > 0 || newMerge
if (notify) {
  const msg = (delta > 0 || solDelta > 0 || solNativeDelta > 0)
    ? `💰 UPLATA PRIMLJENA (${now}) — ${delta > 0 ? `+${delta.toFixed(6)} USDC na Base (ukupno ${usdc})` : ''}${solDelta > 0 ? `+${solDelta.toFixed(6)} USDC na Solani (ukupno ${solUsdcBal})` : ''}${solNativeDelta > 0 ? ` +${solNativeDelta.toFixed(9)} nativnog SOL-a (ukupno ${solNativeBal})` : ''}`
    : `💵 PR SPOJEN (${now}) — pošalji invoice da bi bio plaćen`
  writeFileSync(NOTIFY, msg + '\n')
} else {
  try { unlinkSync(NOTIFY) } catch {}
}

console.log('status:', JSON.stringify(snapshot))
// Glasni CI signali za događaje koji stvarno nose novac — vidljivi u Actions sažetku runa.
if (delta > 0) console.log(`::notice title=UPLATA PRIMLJENA::+${delta.toFixed(6)} USDC na Base — ukupno ${usdc}`)
if (solDelta > 0) console.log(`::notice title=UPLATA PRIMLJENA::+${solDelta.toFixed(6)} USDC na Solani — ukupno ${solUsdcBal}`)
if (solNativeDelta > 0) console.log(`::notice title=UPLATA PRIMLJENA::+${solNativeDelta.toFixed(9)} nativnog SOL-a — ukupno ${solNativeBal}`)
if (newMerge) console.log('::notice title=PR SPOJEN::PR je spojen — pošalji invoice sada')
if (openTask.live?.length) console.log(`::notice title=OPENTASK RAIL ŽIV::metode ${openTask.live.join(', ')} — otvorio se novi izvor zarade`)
if (freshDetail.length) console.log('::notice title=NOVI OGLASI::' + freshDetail.map((o) => `${o.slug} (${o.access}, ${o.reward} ${o.token})`).join(' | '))
