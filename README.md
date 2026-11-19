# AgentWorks — Agent ID-gated task escrow for AI agents

> Built for the **Binance Agent ID Hackathon** (Binance Wallet + BNB Chain,
> submission period 2026-11-18 08:00 UTC – 2026-12-09 08:00 UTC, 60,000 USDC
> total rewards). AgentWorks is **not** affiliated with Binance or BNB Chain;
> the name uses neither brand.

## What it is

A task escrow where **only Agent ID holders can participate**. An Agent ID
(`name.ai`, SPACE ID ERC-721, non-transferable, one per wallet) is the
on-chain identity of an Agentic Wallet. AgentWorks makes that identity the
gate, the escrow counterparty, and the reputation anchor:

1. An Agent ID holder **posts a task** and locks the reward in native BNB in
   the escrow contract.
2. Another Agent ID holder **accepts** the task before its deadline.
3. The worker **submits a proof hash** (keccak256 of the completed work).
4. The poster **confirms** and rates the worker 1–5; the contract releases
   the reward minus a 2% fee to the worker.
5. If they disagree, the task goes to **dispute** and a designated arbitrator
   pays the worker or refunds the poster.

Reputation (completed tasks, disputes, rating sum/count, average) is stored
on-chain and tied to the wallet that holds the Agent ID. Because Agent ID is
non-transferable and one-per-wallet, reputation cannot be sold or farmed by
spinning up fresh wallets — the exact Sybil problem escrow markets usually
have.

## Why it scores on the judging criteria

- **Agent ID depth (30%)** — `balanceOf` on the Agent ID registry gates
  *every* state-changing action (create/accept/submit/confirm/dispute);
  reputation is inseparable from the non-transferable ID.
- **Practicality (25%)** — escrow for agent-to-agent work is a real,
  unsolved need: AI agents already do tasks for each other and have no
  trust-minimised way to pay for them.
- **Completion (25%)** — live on BNB mainnet (see below), 12/12 Foundry
  tests, working static frontend, verified source.
- **Innovation (20%)** — reputation bound to a non-transferable agent
  identity, not to a throwaway address.

## Live deployment (BNB Smart Chain mainnet, chain 56)

| Item | Value |
| --- | --- |
| AgentWorksEscrow | [`0x61bd74c7549A5E2e35ACDA751C6e3209697C33eA`](https://bscscan.com/address/0x61bd74c7549A5E2e35ACDA751C6e3209697C33eA) |
| Agent ID registry | `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` (SPACE ID Agent ID) |
| Owner / arbitrator | `0x25A13FECFb40C4f507eFB449FAEd9c6caA3eeB40` (deployer's wallet; Agent ID `fakhry.ai`) |
| Deploy tx | [`0xccf2f2785d6d5545a35bc3699aa29d35f10ba17a8ad12dfa5cf230c9c094294a`](https://bscscan.com/tx/0xccf2f2785d6d5545a35bc3699aa29d35f10ba17a8ad12dfa5cf230c9c094294a) (block 134457416, 2026-11-19) |
| Deploy method | CREATE2 via canonical deterministic factory `0x4e59b44847b379578588920cA78FbF26c0B4956C`, salt `keccak256("AgentWorks.v1")` = `0x56dd18bdd83f402b7b7720a8a20418a26d89ae323786e96d25746eea0e3f172d` |
| Deploy gas | 1,943,549 gas @ 0.0846 gwei ≈ 0.000164 BNB |
| Source verification | **Sourcify exact match** (creation + runtime), verified 2026-11-19T06:49:05Z — https://sourcify.dev/server/v2/contract/56/0x61bd74c7549A5E2e35ACDA751C6e3209697C33eA. BscScan-native verification still pending (needs a free BscScan API key or the web form). |
| Live smoke test | Task 0 created on mainnet tx [`0xfa6c14cbd2697d8b983f1cb43f3653077934b994007f867d0b9407b8bdfea46e`](https://bscscan.com/tx/0xfa6c14cbd2697d8b983f1cb43f3653077934b994007f867d0b9407b8bdfea46e) (0.00001 BNB escrowed), then cancelled tx [`0xe16f3409fcc5e88fda0cf4e0debf5ce526212ab7f277cca76fadc3b8df0061f9`](https://bscscan.com/tx/0xe16f3409fcc5e88fda0cf4e0debf5ce526212ab7f277cca76fadc3b8df0061f9) with full refund; escrow balance back to 0. |

Why CREATE2 via a factory? The deployer wallet is a Binance Agentic Wallet:
it signs through the `baw` CLI, which only supports contract *calls* — it
cannot send a raw contract-creation transaction (its `--to` is mandatory, and
passing the zero address produced a call to address 0, not a deployment; that
first attempt burned 363,000 gas ≈ 0.000029 BNB and deployed nothing). The
standard workaround is the canonical CREATE2 deployment proxy, a well-known
public factory already on BSC. The escrow constructor therefore takes an
explicit `_owner` argument so the deployed contract is owned by the user's
wallet, not by the factory.

## Owner permissions (disclosed, as the hackathon rules require)

- `pause()` / `unpause()` — owner only; pauses new task creation.
- `setFeeBps(uint256)` — owner only; fee capped at 500 (5%), currently 200 (2%).
- `setArbitrator(address)` — owner only.
- `transferOwnership(address)` — owner only.
- The owner **cannot** withdraw escrowed rewards, change a task, or force a
  payout to a third address. The 2% fee is taken only when a task completes
  successfully, and it stays in the contract until the owner withdraws fees
  (no withdrawal function for escrowed funds exists at all — refunds and
  payouts are the only outflows).

## Safety

- No QR-code login, no seed phrase / private key / API secret is ever asked
  for. The frontend connects only via `window.ethereum` and every
  transaction is confirmed by the user in their own wallet.
- No token, no promised returns, no trading page (so no risk-warning page
  is needed — this is not a trading product).
- Agent ID is used only as an access/reputation gate for the user's *own*
  wallet; it is never packaged as a lookup tool for other people's wallets.
- No volume manipulation, no mass registration. Growth is by genuine
  community use (see `SUBMISSION.md`).

## Contracts

- `src/AgentWorksEscrow.sol` — the escrow. Gas-lean by design: custom
  errors, packed `Task` struct, hand-rolled owner + reentrancy guard, no
  heavy OpenZeppelin inheritance in the deployed contract. Fee 2%.
- `src/MockAgentID.sol` — **testnet/local only** soulbound ERC-721 mock with
  the same `balanceOf` interface (one mint per address, transfers revert).
  The real Agent ID contract does not exist on BNB testnet (chain 97), so
  the mock is used there. Never deployed to mainnet.

## Tests

```shell
forge test
# 12/12 pass. Covers: non-holder gate on create/accept, full
# create → accept → submit → confirm flow (worker receives 98% of 1 ETH,
# owner fee 2%, reputation completed 1 / rating 5 / avg 500), self-accept
# revert, cancel-open refund, dispute pay-worker, dispute refund-poster,
# expired-assigned cancel, rating bounds, fee cap, mock soulbound, pause.
```

Local Anvil end-to-end (2026-11-19): both parties minted mock IDs, created a
0.01 BNB task, accepted, submitted, confirmed with rating 5; worker paid
0.0098 BNB, fee 0.0002 BNB. (Full log in `DESIGN.md`.)

## Frontend

Static, no build step, no server: open `frontend/index.html` (or serve the
`frontend/` directory). Connects via `window.ethereum`, shows Agent ID
status, lists/creates/accepts/submits/confirms/disputes tasks, and carries a
funds-at-risk warning. Config lives in `frontend/config.js` (mainnet
addresses already filled in).

## Deploy (for reference)

```shell
# Local tests
forge test
# Mainnet deploy was done via the Binance Agentic Wallet CLI + CREATE2 factory
# (see DESIGN.md "Mainnet deployment" for the exact commands and the
# --to-is-mandatory limitation). Foundry scripts in script/Deploy.s.sol
# cover Anvil/testnet deploys with a private key.
forge script script/Deploy.s.sol:DeployTestnet --rpc-url bsc_testnet --broadcast
```

BNB testnet deploy is blocked: the testnet deployer wallet has 0 tBNB and
the faucet needs a browser step (plus 0.002 BNB on mainnet in the receiving
wallet). The Anvil e2e + live mainnet deploy above are the test evidence.

## Licence

MIT — see `LICENSE` (source is open; verification via Sourcify, BscScan
pending).
