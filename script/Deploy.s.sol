// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/AgentWorksEscrow.sol";
import "../src/MockAgentID.sol";

/// @notice Deploy AgentWorks.
/// Usage:
///   # Testnet (chain 97) — MockAgentID first, then escrow pointing at it:
///   forge script script/Deploy.s.sol:DeployTestnet --rpc-url bsc_testnet --broadcast
///   # Mainnet (chain 56) — escrow pointing at the REAL Agent ID registry.
///   # DO NOT run mainnet without user approval; see SUBMISSION.md.
///   forge script script/Deploy.s.sol:DeployMainnet --rpc-url bsc --broadcast
/// Env: PRIVATE_KEY (testnet-only deployer key for testnet; never a mainnet
/// key with real funds unless the user explicitly approves the mainnet step).
contract DeployTestnet is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        MockAgentID mock = new MockAgentID();
        console.log("MockAgentID:", address(mock));
        AgentWorksEscrow escrow = new AgentWorksEscrow(address(mock), vm.addr(pk), vm.addr(pk));
        console.log("AgentWorksEscrow:", address(escrow));
        console.log("Agent ID registry used:", address(mock));
        console.log("Owner/arbitrator:", vm.addr(pk));
        vm.stopBroadcast();
    }
}

contract DeployMainnet is Script {
    address public constant REAL_AGENT_ID = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        AgentWorksEscrow escrow = new AgentWorksEscrow(REAL_AGENT_ID, vm.addr(pk), vm.addr(pk));
        console.log("AgentWorksEscrow:", address(escrow));
        console.log("Agent ID registry used:", REAL_AGENT_ID);
        console.log("Owner/arbitrator:", vm.addr(pk));
        vm.stopBroadcast();
    }
}
