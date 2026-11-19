// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockAgentID — TESTNET ONLY soulbound Agent ID stand-in
/// @notice The real SPACE ID Agent ID contract (0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F)
/// does NOT exist on BNB testnet (chain 97). This mock exposes the same
/// `balanceOf(address)` interface so AgentWorksEscrow can be tested end to
/// end on testnet. One mint per address, transfers always revert.
/// NEVER deploy this to mainnet; mainnet uses the real registry address.
contract MockAgentID is ERC721, Ownable {
    uint256 private nextTokenId = 1;
    mapping(address => bool) public hasMinted;

    error AlreadyMinted();
    error Soulbound();

    constructor() ERC721("MockAgentID (TEST ONLY)", "MOCK-AI") Ownable(msg.sender) {}

    /// @notice Mint one test Agent ID to the caller. Testnet only.
    function mint() external returns (uint256 tokenId) {
        if (hasMinted[msg.sender]) revert AlreadyMinted();
        hasMinted[msg.sender] = true;
        tokenId = nextTokenId++;
        _safeMint(msg.sender, tokenId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        returns (address)
    {
        address from = _ownerOf(tokenId);
        // Allow minting (from == 0); block every transfer / burn.
        if (from != address(0)) revert Soulbound();
        return super._update(to, tokenId, auth);
    }
}
