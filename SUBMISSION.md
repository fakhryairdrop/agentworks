# AgentWorks — Binance Agent ID Hackathon submission materials

**Status: READY TO SUBMIT except the submission channel — see "Submission
channel" below. Nothing has been submitted yet. Do NOT claim it has.**

## Project

- **Name:** AgentWorks
- **Tagline:** Agent ID-gated task escrow for AI agents — only Agent ID
  holders can post and accept tasks; rewards are escrowed in BNB and
  released on completion; reputation is tied to the non-transferable Agent ID.
- **Announcement:** https://www.binance.com/en/support/announcement/detail/95f5dbe0ea674a48a739b59e046648bf
- **Submission period:** 2026-11-18 08:00 UTC – 2026-12-09 08:00 UTC
- **Team:** individual — fakhry (Agent ID `fakhry.ai`)

## Website / demo

- **Demo frontend:** `frontend/` in this repo (static HTML/JS, no build
  step, no server). Open `frontend/index.html` or serve the directory.
  Config (`frontend/config.js`) already points at the mainnet contract.
- **Public hosting: IN PROGRESS — 2026-11-19 ~14:55 WIB.** Local repo is
  committed (branch `main`, commit `a8a72ff`, 88 files) and the frontend
  was verified serving locally (index/config/app all HTTP 200, config
  points at mainnet escrow 0x61bd74c7549A5E2e35ACDA751C6e3209697C33eA).
  Repo `fakhryairdrop/agentworks` does NOT exist yet on GitHub (checked
  2026-11-19, 404). Still needed, via the GitHub website in the browser:
  create public repo `fakhryairdrop/agentworks`, push this commit, then
  enable GitHub Pages (branch `main`, folder `/frontend`). Expected
  website URL after that (NOT yet verified live — do not use in the
  submission form until verified loading):
  `https://fakhryairdrop.github.io/agentworks/` and repo
  `https://github.com/fakhryairdrop/agentworks`.
- **Code (open source, MIT):** this repo — `src/AgentWorksEscrow.sol`,
  `src/MockAgentID.sol` (testnet only), `test/AgentWorks.t.sol`,
  `script/Deploy.s.sol`, `frontend/`, `DESIGN.md`, `README.md`.

## Contract addresses (BNB Smart Chain mainnet, chain 56)

| Contract | Address |
| --- | --- |
| AgentWorksEscrow | `0x61bd74c7549A5E2e35ACDA751C6e3209697C33eA` — https://bscscan.com/address/0x61bd74c7549A5E2e35ACDA751C6e3209697C33eA |
| Agent ID registry (SPACE ID Agent ID, ERC-721, non-transferable) | `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` |
| CREATE2 factory used for deployment | `0x4e59b44847b379578588920cA78FbF26c0B4956C` (canonical deterministic deployment proxy) |

- **Deploy tx:** https://bscscan.com/tx/0xccf2f2785d6d5545a35bc3699aa29d35f10ba17a8ad12dfa5cf230c9c094294a
  (block 134457416, 2026-11-19, 1,943,549 gas @ 0.0846 gwei ≈ 0.000164 BNB)
- **Source verification:** Sourcify **exact match** (creation + runtime),
  verified 2026-11-19T06:49:05Z —
  https://sourcify.dev/server/v2/contract/56/0x61bd74c7549A5E2e35ACDA751C6e3209697C33eA
  — BscScan-native verification still pending (needs a free BscScan API key
  or the BscScan web verification form).
- **Live smoke test on mainnet:** task 0 created —
  https://bscscan.com/tx/0xfa6c14cbd2697d8b983f1cb43f3653077934b994007f867d0b9407b8bdfea46e
  (216,759 gas, 0.00001 BNB escrowed) — then cancelled with full refund —
  https://bscscan.com/tx/0xe16f3409fcc5e88fda0cf4e0debf5ce526212ab7f277cca76fadc3b8df0061f9
  (64,856 gas); escrow balance back to 0.
- **Tests:** `forge test` — 12/12 pass. Local Anvil end-to-end also passed
  (create → accept → submit → confirm, rating 5, worker paid 98%, fee 2%).
- **Testnet deploy: NOT done** — blocked on tBNB (faucet needs a browser
  step; see DESIGN.md). Mainnet deploy + smoke test are the live evidence.

## Agent ID usage description (for the submission form)

> AgentWorks uses Agent ID as the core identity layer, not as a cosmetic
> badge. Every state-changing function — `createTask`, `acceptTask`,
> `submitWork`, `confirmCompletion`, `disputeTask` — first calls
> `balanceOf(msg.sender)` on the SPACE ID Agent ID registry
> (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`); a caller without an Agent ID
> reverts. The escrow counterparty is therefore always a named agent
> (`name.ai`), and on-chain reputation (completed tasks, disputes, rating
> sum/count, average) is stored per wallet and inseparable from the
> non-transferable, one-per-wallet Agent ID — so reputation cannot be sold,
> transferred, or farmed by creating fresh wallets. This is what makes
> agent-to-agent escrow trustworthy: the same identity that posts the work
> is the one that carries its history.

## Owner permissions (disclosed)

Owner (`0x25A13FECFb40C4f507eFB449FAEd9c6caA3eeB40`): pause/unpause, set fee
≤ 5% (currently 2%), set arbitrator, transfer ownership. The owner cannot
withdraw escrowed rewards, change tasks, or force a payout to a third
address. Arbitrator (same address for now): resolves disputes by paying the
worker or refunding the poster. Full details in `README.md` / `DESIGN.md`.

## Reward receiving address

`0x25A13FECFb40C4f507eFB449FAEd9c6caA3eeB40` (user's Binance Agentic Wallet
EVM address; Agent ID `fakhry.ai`). Confirm with the user before submitting
— this is the address rewards would be sent to.

## Submission channel — ⚠️ NOT FOUND YET, ACTION NEEDED

The Binance announcement instructs projects to "submit your project name,
website, contract address(es), Agent ID usage description, and other
required materials during the Submission Period. No registration needed"
— **but the announcement page contains no project-submission form or link**
(checked 2026-11-19; the only link in it is the `app.binance.com` campaign
survey for the *X promotion* award, not for project submission). A web
search also surfaced no submission form.

**What to do next (needs a live browser, parent agent):**
1. Open the announcement in a live browser and look for a submission
   button/form that the text fetch may have missed.
2. Check the Binance Wallet Agentic Wallet / Agent ID ecosystem page
   (the announcement says outstanding projects are featured there) for a
   "submit project" entry point.
3. If neither exists, the likely route is the same `app.binance.com`
   survey — verify its title/fields before using it, and do **not** guess a
   URL.
4. Once the channel is found, submit exactly the materials above
   (name, website/demo, contract address, Agent ID usage description,
   reward receiving address) and record the confirmation/screenshot as
   proof. Deadline: **2026-12-09 08:00 UTC**.

## Plan to reach 30+ interacting Agent ID holders (no fake volume)

The Innovation Award requires a live product + ≥ 30 Agent ID addresses
interacting during the submission period. Current count: **1** (the
deployer's own smoke-test task; the task was created and cancelled, so it
counts as one interacting address at most). Honest growth plan only —
no volume manipulation, no mass registration, no paid/fake interactions:

1. **Publish the code + demo** (GitHub repo under `fakhryairdrop`, public
   hosting for the frontend) so anyone can verify and use it.
2. **Post real tasks on AgentWorks** — e.g. small paid tasks for agents
   (summarise a doc, check a contract, write a test) with real BNB rewards
   funded by the deployer; each task brings at least two Agent ID holders
   (poster + worker) on-chain.
3. **Community outreach:** share the project in Binance Wallet / BNB Chain
   community channels, AI-agent builder groups, and the make.fun / agent
   communities the user already works in; invite agent builders to try a
   task, not to "farm" interactions.
4. **X promotion (draft below, DO NOT POST without user approval):** one
   original post about the project with `#BinanceWalletHackathon`
   `#AgenticWallet`, then submit the X link via the official campaign
   survey — this also enters the $2,000 Community Promotion pool (20
   winners share equally).
5. **Track weekly:** interacting Agent ID addresses + tx count on the
   escrow contract (BscScan / BSC RPC), and record them here.

### X post draft (needs user approval before posting)

> Built AgentWorks for the @BinanceWallet Agent ID Hackathon: an escrow
> where only Agent ID holders can post & accept tasks — rewards locked in
> BNB, released on completion, reputation tied to your non-transferable
> name.ai. Live on BNB Chain:
> https://bscscan.com/address/0x61bd74c7549A5E2e35ACDA751C6e3209697C33eA
> #BinanceWalletHackathon #AgenticWallet

## Spending / safety record for this submission

- No USDC spent. No X post made. No seed phrase / private key used or
  asked for (deploy signed through the Binance Agentic Wallet CLI).
- Total BNB spent on deploy + live smoke test: ≈ 0.000215 BNB
  (deploy 0.000164 + createTask 0.000015 + cancelTask 0.000006 + one
  failed first attempt 0.000029), from the user's approved balance.
  Remaining balance: 0.000707720996827907 BNB.
- One failed deployment attempt is documented honestly in DESIGN.md
  (zero-address call, deployed nothing, 0.000029 BNB).
