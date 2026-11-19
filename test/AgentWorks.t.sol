// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AgentWorksEscrow.sol";
import "../src/MockAgentID.sol";

contract AgentWorksTest is Test {
    MockAgentID mock;
    AgentWorksEscrow escrow;
    address poster = makeAddr("poster");
    address worker = makeAddr("worker");
    address stranger = makeAddr("stranger"); // no Agent ID
    address owner;

    // Accept the 2% fee in tests (owner = this test contract).
    receive() external payable {}

    function setUp() public {
        mock = new MockAgentID();
        owner = address(this);
        escrow = new AgentWorksEscrow(address(mock), address(this), address(this));
        vm.deal(poster, 10 ether);
        vm.deal(worker, 1 ether);
        vm.deal(stranger, 1 ether);
        vm.prank(poster);
        mock.mint();
        vm.prank(worker);
        mock.mint();
    }

    function _create(uint256 reward) internal returns (uint256 id) {
        vm.prank(poster);
        id = escrow.createTask{value: reward}("Write a report", keccak256("spec"), uint64(block.timestamp + 1 days));
    }

    function testGateNonHolderCannotCreate() public {
        vm.prank(stranger);
        vm.expectRevert(AgentWorksEscrow.NotAgentIdHolder.selector);
        escrow.createTask{value: 0.1 ether}("x", bytes32(0), uint64(block.timestamp + 1 days));
    }

    function testGateNonHolderCannotAccept() public {
        uint256 id = _create(1 ether);
        vm.prank(stranger);
        vm.expectRevert(AgentWorksEscrow.NotAgentIdHolder.selector);
        escrow.acceptTask(id);
    }

    function testCreateAcceptSubmitConfirmPaysWorkerMinusFee() public {
        uint256 id = _create(1 ether);
        vm.prank(worker);
        escrow.acceptTask(id);
        vm.prank(worker);
        escrow.submitWork(id, keccak256("deliverable"));
        uint256 wBefore = worker.balance;
        uint256 oBefore = owner.balance;
        vm.prank(poster);
        escrow.confirmCompletion(id, 5);
        assertEq(worker.balance - wBefore, 0.98 ether, "worker gets 98%");
        assertEq(owner.balance - oBefore, 0.02 ether, "owner fee 2%");
        (uint32 completed, uint32 disputed, uint32 sum, uint32 count, uint256 avg) =
            escrow.getReputation(worker);
        assertEq(completed, 1);
        assertEq(disputed, 0);
        assertEq(sum, 5);
        assertEq(count, 1);
        assertEq(avg, 500);
        assertEq(address(escrow).balance, 0);
    }

    function testSelfAcceptReverts() public {
        uint256 id = _create(1 ether);
        vm.prank(poster);
        vm.expectRevert(AgentWorksEscrow.SelfAccept.selector);
        escrow.acceptTask(id);
    }

    function testCancelOpenRefundsPoster() public {
        uint256 id = _create(1 ether);
        uint256 before = poster.balance;
        vm.prank(poster);
        escrow.cancelTask(id);
        assertEq(poster.balance - before, 1 ether);
    }

    function testDisputePayWorker() public {
        uint256 id = _create(1 ether);
        vm.prank(worker);
        escrow.acceptTask(id);
        vm.prank(worker);
        escrow.submitWork(id, keccak256("d"));
        vm.prank(poster);
        escrow.raiseDispute(id);
        uint256 wBefore = worker.balance;
        escrow.resolveDispute(id, true); // owner is arbitrator in setUp
        assertEq(worker.balance - wBefore, 0.98 ether);
    }

    function testDisputeRefundPoster() public {
        uint256 id = _create(1 ether);
        vm.prank(worker);
        escrow.acceptTask(id);
        vm.prank(poster);
        escrow.raiseDispute(id);
        uint256 before = poster.balance;
        escrow.resolveDispute(id, false);
        assertEq(poster.balance - before, 1 ether);
    }

    function testExpiredAssignedCanBeCancelled() public {
        uint256 id = _create(1 ether);
        vm.prank(worker);
        escrow.acceptTask(id);
        vm.warp(block.timestamp + 2 days);
        uint256 before = poster.balance;
        vm.prank(poster);
        escrow.cancelTask(id);
        assertEq(poster.balance - before, 1 ether);
    }

    function testRatingBounds() public {
        uint256 id = _create(1 ether);
        vm.prank(worker);
        escrow.acceptTask(id);
        vm.prank(worker);
        escrow.submitWork(id, keccak256("d"));
        vm.prank(poster);
        vm.expectRevert(AgentWorksEscrow.InvalidRating.selector);
        escrow.confirmCompletion(id, 6);
    }

    function testFeeCap() public {
        vm.expectRevert(AgentWorksEscrow.InvalidFee.selector);
        escrow.setFee(501);
        escrow.setFee(500);
        assertEq(escrow.feeBps(), 500);
    }

    function testMockIsSoulbound() public {
        vm.prank(poster);
        vm.expectRevert(MockAgentID.Soulbound.selector);
        mock.transferFrom(poster, worker, 1);
        assertEq(mock.balanceOf(poster), 1);
        assertEq(mock.balanceOf(stranger), 0);
    }

    function testPauseBlocksCreate() public {
        escrow.setPaused(true);
        vm.prank(poster);
        vm.expectRevert(AgentWorksEscrow.Paused.selector);
        escrow.createTask{value: 0.1 ether}("x", bytes32(0), uint64(block.timestamp + 1 days));
    }
}
