# AgentWorks — Design

**Project name:** AgentWorks
**Tagline:** Agent ID-gated task escrow for AI agents on BNB Chain.
**Hackathon:** Binance Agent ID Hackathon, submission 2026-11-18 08:00 UTC – 2026-12-09 08:00 UTC.
**Repo / workspace:** `~/workspace/binance-agent-id-hackathon/`
**Licence:** MIT. No "Binance" / "BNB" in the project name, token name, or domain — AgentWorks is an independent project that *reads* the public Agent ID registry; it is not affiliated with Binance or SPACE ID.

## Problem

AI agents can already hold wallets and sign transactions, but hiring an agent is still
trust-based: a poster pays up front and hopes, or a worker works first and hopes to be
paid. There is no portable, Sybil-resistant reputation for agents — a bad actor can
abandon a wallet and start over with a fresh address at zero cost.

Agent ID changes that: it is a non-transferable (soulbound) ERC-721, one per wallet,
`name.ai`. An agent cannot sell, lend, or re-create its Agent ID. Reputation tied to
the wallet that holds an Agent ID is therefore reputation tied to a scarce,
non-transferable identity.

## Solution — AgentWorks

A task escrow where **every** state-changing action requires the caller to hold an
Agent ID (`balanceOf(caller) > 0` on the SPACE ID Agent ID contract
`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` on BNB Smart Chain, chain 56).

Flow:
1. **Post** — an Agent ID holder creates a task with a title, a content hash
   (description / spec, stored off-chain, e.g. IPFS), a deadline, and locks the
   reward in native BNB in the contract.
2. **Accept** — another Agent ID holder accepts the task. Poster cannot accept
   their own task.
3. **Submit** — the worker submits a proof hash (deliverable hash) before the deadline.
4. **Confirm** — the poster confirms completion and rates the worker 1–5. The
   contract releases `reward − 2% fee` to the worker and the 2% fee to the owner.
5. **Dispute** — poster or worker can dispute a submitted/assigned task. The
   arbitrator (initially the owner, changeable) resolves: pay the worker or refund
   the poster. No party can move funds unilaterally.
6. **Cancel / expire** — an open task can be cancelled by its poster for a full
   refund; an assigned task past its deadline with no submission can be cancelled
   by the poster for a full refund.

Reputation is on-chain and tied to the Agent ID wallet: completed tasks, disputes,
rating sum/count, and average rating are readable per address. Because the ID is
soulbound, a worker cannot shed a bad reputation by transferring the ID, and a
poster cannot create a fresh "trusted" identity for free.

## Why this scores well (100-point criteria)

| Dimension (weight) | How AgentWorks scores |
|---|---|
| Agent ID depth — 30% | Agent ID is not a badge on the homepage: it gates **every** write (post, accept, submit, confirm, dispute). Reputation is keyed to the Agent ID wallet. The contract reads `balanceOf` on every gated call, so a wallet that somehow lost its ID instantly loses access. No function is usable without an Agent ID. |
| Practicality & feasibility — 25% | Hiring agents is the most immediate real use of agentic wallets: agents already write code, research, and run tasks for people. Escrow + dispute + reputation is a proven marketplace pattern (Upwork/Fiverr logic, on-chain). One contract, native BNB, no token, no oracle, no off-chain server in the trust path. |
| Completion — 25% | Live product: one Foundry contract + a working static frontend (connect wallet, check Agent ID, list/create/accept/submit/confirm/dispute tasks). Full Foundry test suite, gas report, testnet deployment + BscScan verification. |
| Innovation — 20% | Soulbound-reputation escrow for *agents hiring agents*: the same contract serves human→agent, agent→agent, and agent→human work, with reputation that cannot be transferred or reset. This is a use case that only exists because Agent ID is non-transferable — it would not work with a normal NFT. |

## Alternatives considered (and rejected)

- **Agent ID-gated NFT mint** — the most common pattern in the ecosystem already
  (many mint gates exist). Low differentiation, thin Agent ID depth (one check at
  mint), no ongoing business flow. Rejected.
- **Agent ID-gated token / airdrop** — promises value, invites Sybil farming, and
  risks the "promise returns" red line. Rejected.
- **Agent ID name lookup / directory** — explicitly prohibited as a red line
  ("Agent ID must not be packaged as a tool to look up other people's wallets by
  name"). Rejected outright.
- **Prediction / trading product** — needs risk warnings, oracles, and promises
  nothing useful for agents; high complexity, low Agent ID depth. Rejected.

## Contracts

### `AgentWorksEscrow.sol` (mainnet target)

- `IAgentID` interface: only `balanceOf(address) returns (uint256)`. No other
  Agent ID function is needed; name resolution is deliberately **not** used
  (no wallet-by-name lookup).
- Gas-efficient on purpose: custom errors (no revert strings), packed `Task`
  struct, minimal storage, hand-rolled `Ownable`-style owner + reentrancy guard
  (no heavy OZ inheritance in the deployed contract — OZ is used only for the
  testnet mock and for `forge-std` in tests). Deploy target was < 1.2M gas;
  measured optimised deploy is 1,938,183 gas — above target, but at
  ~0.05–0.085 gwei it still cost only ~0.00010–0.00016 BNB, within budget.
- State machine: `Open → Assigned → Submitted → Completed`, with `Disputed`
  (from Assigned/Submitted) → `Completed` (pay worker) or `Refunded`,
  `Open → Cancelled` (refund), `Assigned → Cancelled` after deadline
  (refund, poster only).
- Fee: 2% (`feeBps = 200`, max 500 = 5%), taken only on a successful release
  to the worker. No fee on refunds or cancellations.
- Owner permissions (disclosed, per hackathon rules): owner can pause/unpause,
  set fee (≤ 5%), set arbitrator, set fee recipient is the owner address.
  Owner **cannot** withdraw escrowed rewards, seize a task's funds, change a
  task, or force a payout to anyone except via `resolveDispute` as arbitrator
  (pay worker OR refund poster — never to a third address).
- Security: `nonReentrant` on all fund-moving functions, checks-effects-
  interactions, deadline checks, poster ≠ worker, rating 1–5, no unlimited
  approvals anywhere (the contract never calls `transferFrom` / never asks for
  token approvals — rewards are native BNB sent with the task creation).

### `MockAgentID.sol` (testnet only)

- The real Agent ID contract **does not exist on BNB testnet (chain 97)**
  (verified: `balanceOf` call on testnet reverts "no code at address").
  The mock is a soulbound ERC-721 with the same `balanceOf` interface:
  one mint per address, transfers revert. It is labelled `MockAgentID` /
  "TEST ONLY" everywhere and is **never** deployed to mainnet.
- Mainnet deployment uses the real registry address
  `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` as the constructor argument;
  testnet deployment uses the mock address. The escrow contract is identical
  in both cases — only the constructor argument changes.

## Frontend

Static `frontend/index.html` + `app.js` (no build step, no server, no QR login,
no session storage on any server). The user connects their own wallet
(MetaMask / Binance Wallet via `window.ethereum`), signs nothing except the
transactions they explicitly confirm in their own wallet. The page:
- reads `balanceOf` for the connected address and shows Agent ID status;
- lists tasks from the contract, creates/accepts/submits/confirms/disputes;
- shows a plain-language risk warning: escrowed funds are real, disputes are
  resolved by the arbitrator, and no return is promised.
- never asks for a seed phrase, private key, API secret, or pairing code.

## Safety red lines — compliance checklist

- [x] No web QR-code login, no pairing codes, no server-stored sessions.
- [x] No bypass of user transaction confirmation — every fund move is a
  transaction the user signs in their own wallet.
- [x] No unauthorized transfers, no scheduled collection, no bundled extra
  transfers, no unlimited approvals.
- [x] Contracts open-source, owner permissions disclosed above and in README.
- [x] No Binance/BNB brand impersonation in name, token, or domain.
- [x] No collection of seed phrases / private keys / API secrets / pairing codes.
- [x] No promised returns, no "passive income" language.
- [x] No trading page, so no trading risk warning is required; the task page
  still carries a funds-at-risk warning.
- [x] Agent ID is used as an access/reputation gate, never as a
  wallet-by-name lookup tool.
- [x] No volume manipulation, no mass account registration. Growth plan in
  `SUBMISSION.md` is community/outreach only, with real Agent ID holders.

## Gas & funding (updated 2026-11-19 ~13:55 WIB — mainnet deploy DONE)

- User's BSC BNB balance before deploy: **0.000922876522142592 BNB (~$0.54
  at $588.64)**. After deploy + live smoke test: **0.000707720996827907 BNB
  (~$0.42)**.
- BSC gas price at deploy time: **0.071–0.090 gwei** (low ~0.052, medium
  ~0.082 gwei at preview time).
- Measured mainnet numbers (2026-11-19):
  - Deploy (CREATE2 via factory): **1,943,549 gas @ 0.0846 gwei ≈
    0.000164 BNB** (~$0.096). Optimised build was 1,938,183 gas in Forge
    estimates; the factory wrapper added ~5k.
  - Live `createTask`: 216,759 gas @ 0.0711 gwei ≈ 0.0000154 BNB
    (+ 0.00001 BNB reward, refunded on cancel).
  - Live `cancelTask`: 64,856 gas @ 0.0901 gwei ≈ 0.0000058 BNB.
  - Failed first attempt (see below): 363,000 gas ≈ 0.0000294 BNB.
  - Total spent on deploy + smoke test: ≈ **0.000215 BNB**.

## Mainnet deployment (2026-11-19, user-approved)

- **Contract: `0x61bd74c7549A5E2e35ACDA751C6e3209697C33eA`**
  (BSC mainnet, chain 56), owner/arbitrator =
  `0x25A13FECFb40C4f507eFB449FAEd9c6caA3eeB40`, Agent ID registry =
  `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`, fee 200 bps (2%).
- Deploy tx: `0xccf2f2785d6d5545a35bc3699aa29d35f10ba17a8ad12dfa5cf230c9c094294a`
  (block 134457416, status 1). Verified on-chain: code present, `owner()`
  / `agentId()` / `feeBps()` / `hasAgentId(user) = true` all read back
  correctly.
- **Method — CREATE2 via the canonical deterministic factory
  `0x4e59b44847b379578588920cA78FbF26c0B4956C`**, salt
  `keccak256("AgentWorks.v1")`. The escrow constructor takes an explicit
  `_owner` argument (added for this) so the factory-deployed contract is
  owned by the user's wallet, not by the factory. Predicted address was
  computed with `cast create2` and confirmed by an `eth_call` simulation
  before broadcasting.
- **Why not a direct creation tx:** the Binance Agentic Wallet CLI (`baw
  contract-call`) requires `--to` and can only *call* existing contracts —
  it cannot send a contract-creation transaction. A first attempt with
  `--to 0x0000000000000000000000000000000000000000` was executed as a
  *call to address 0* with the bytecode as calldata (tx
  `0x4af227ca5238e25854823786156febdaf7d16276ed04954c7c68c832ec9d5b01`,
  status 1, `contractAddress: null`, 363,000 gas ≈ 0.000029 BNB wasted).
  It deployed nothing. The CREATE2 factory call is the standard,
  legitimate workaround and the contract is fully verified (Sourcify exact
  match, 2026-11-19T06:49:05Z; BscScan-native verification still pending —
  needs a free BscScan API key or the web form).
- **Testnet deploy: NOT done (blocked).** Testnet deployer
  `0xE0728f679749D3E4f301Fa2C0Cc863Ac673E0b2d` has 0 tBNB; the faucet is a
  JS web form needing wallet connect/captcha and 0.002 BNB on mainnet in
  the receiving wallet. Evidence instead: 12/12 Foundry tests, a full
  local Anvil end-to-end run, and the live mainnet smoke test (task 0
  created then cancelled with full refund, escrow balance back to 0).

## Open questions for the user (approval needed, not blockers for building)

1. ~~Mainnet deploy funding~~ — DONE with user approval (see above).
2. Reward receiving address for the hackathon submission: user's wallet
   `0x25A13FECFb40C4f507eFB449FAEd9c6caA3eeB40` (assumed; confirm).
3. Project name/hosting: `AgentWorks` is proposed; website hosting (static
   frontend) is TBD — local `frontend/` works, public hosting needs a decision.
4. X promotion post (draft in SUBMISSION.md) — do not post without approval.
5. **Submission channel: NOT FOUND YET.** The Binance announcement says to
   "submit your project name, website, contract address(es), Agent ID usage
   description, and other required materials" but contains no project
   submission form/link (only the X-promotion survey link). Needs a live
   browser check of the announcement page / Binance Wallet ecosystem page —
   see SUBMISSION.md.
