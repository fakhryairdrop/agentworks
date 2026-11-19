// AgentWorks frontend — vanilla JS + ethers v6, no server, no QR login.
// Every fund movement is a transaction the user confirms in their own wallet.
const ESCROW_ABI = [
  "function hasAgentId(address) view returns (bool)",
  "function taskCount() view returns (uint256)",
  "function getTask(uint256) view returns (tuple(address poster,address worker,uint128 reward,uint64 deadline,uint64 createdAt,uint8 status,uint8 rating,bytes32 descriptionHash,bytes32 proofHash,string title))",
  "function getReputation(address) view returns (uint32,uint32,uint32,uint32,uint256)",
  "function createTask(string,bytes32,uint64) payable returns (uint256)",
  "function acceptTask(uint256)",
  "function submitWork(uint256,bytes32)",
  "function confirmCompletion(uint256,uint8)",
  "function raiseDispute(uint256)",
  "function cancelTask(uint256)",
  "function feeBps() view returns (uint256)"
];
const AGENT_ABI = ["function balanceOf(address) view returns (uint256)"];
const STATUS = ["Open", "Assigned", "Submitted", "Completed", "Disputed", "Cancelled", "Refunded"];

let provider, signer, escrow, account;

function el(id) { return document.getElementById(id); }
function escrowAddr() { return window.AGENTWORKS_CONFIG.escrowAddress; }

async function connect() {
  if (!window.ethereum) { el("status").textContent = "No wallet found (window.ethereum)."; return; }
  provider = new ethers.BrowserProvider(window.ethereum);
  await provider.send("eth_requestAccounts", []);
  signer = await provider.getSigner();
  account = await signer.getAddress();
  const net = await provider.getNetwork();
  el("status").textContent = "Connected: " + account;
  el("network").textContent = "chain " + net.chainId;
  el("escrowAddr").textContent = escrowAddr() || "not deployed yet — see config.js";
  if (escrowAddr()) {
    escrow = new ethers.Contract(escrowAddr(), ESCROW_ABI, signer);
    const agent = new ethers.Contract(window.AGENTWORKS_CONFIG.agentIdAddress, AGENT_ABI, provider);
    const bal = await agent.balanceOf(account);
    el("agentStatus").textContent = bal > 0n ? "holds an Agent ID ✓" : "NO Agent ID — you cannot post or accept tasks";
    await loadTasks();
  } else {
    el("agentStatus").textContent = "escrow not deployed yet";
  }
}

async function loadTasks() {
  const n = Number(await escrow.taskCount());
  const box = el("tasks");
  box.innerHTML = "";
  if (n === 0) { box.innerHTML = "<p>No tasks yet. Post the first one.</p>"; return; }
  for (let i = n - 1; i >= 0; i--) {
    const t = await escrow.getTask(i);
    const div = document.createElement("div");
    div.className = "card";
    div.innerHTML = "<strong>#" + i + " " + escapeHtml(t.title) + "</strong><br>" +
      "Status: " + STATUS[t.status] + " · Reward: " + ethers.formatEther(t.reward) + " BNB<br>" +
      "Poster: <code>" + t.poster + "</code><br>Worker: <code>" + t.worker + "</code><br>" +
      "Deadline: " + new Date(Number(t.deadline) * 1000).toLocaleString();
    const mk = (label, fn) => {
      const b = document.createElement("button"); b.textContent = label;
      b.onclick = async () => { try { const tx = await fn(); await tx.wait(); await loadTasks(); } catch (e) { alert(e.message || e); } };
      div.appendChild(b);
    };
    if (t.status === 0) mk("Accept", () => escrow.acceptTask(i));
    if (t.status === 1 && t.worker.toLowerCase() === account.toLowerCase())
      mk("Submit work", () => { const p = prompt("Proof hash (0x… bytes32) or leave blank for zero hash:"); return escrow.submitWork(i, p || ethers.ZeroHash); });
    if (t.status === 2 && t.poster.toLowerCase() === account.toLowerCase())
      mk("Confirm + rate 5", () => escrow.confirmCompletion(i, 5));
    if ((t.status === 1 || t.status === 2)) mk("Dispute", () => escrow.raiseDispute(i));
    if (t.status === 0 && t.poster.toLowerCase() === account.toLowerCase())
      mk("Cancel (refund)", () => escrow.cancelTask(i));
    box.appendChild(div);
  }
}

function escapeHtml(s) { return String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])); }

el("connectBtn").onclick = connect;
el("createBtn").onclick = async () => {
  if (!escrow) { alert("Connect first, and deploy the escrow contract (see config.js)."); return; }
  const title = el("title").value.trim();
  const desc = el("desc").value;
  const reward = el("reward").value;
  const days = Number(el("deadline").value || "7");
  const deadline = Math.floor(Date.now() / 1000) + days * 86400;
  try {
    const tx = await escrow.createTask(title, ethers.keccak256(ethers.toUtf8Bytes(desc)), deadline, { value: ethers.parseEther(reward) });
    await tx.wait();
    await loadTasks();
  } catch (e) { alert(e.message || e); }
};
