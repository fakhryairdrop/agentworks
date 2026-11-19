// AgentWorks frontend config — BNB Smart Chain mainnet (chain 56).
// Escrow deployed 2026-11-19 via the canonical CREATE2 factory
// (0x4e59b44847b379578588920cA78FbF26c0B4956C), salt keccak256("AgentWorks.v1").
window.AGENTWORKS_CONFIG = {
  chainId: 56, // BNB Smart Chain mainnet
  escrowAddress: "0x61bd74c7549A5E2e35ACDA751C6e3209697C33eA",
  agentIdAddress: "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F", // SPACE ID Agent ID (ERC-721, non-transferable)
  agentIdAddressMainnet: "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F",
  rpcUrl: "https://bsc-dataseed1.bnbchain.org",
  explorer: "https://bscscan.com"
};
