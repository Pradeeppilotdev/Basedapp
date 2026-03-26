// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SimpleLottery} from "../src/SimpleLottery.sol";

contract SimpleLotteryTest is Test {
    SimpleLottery public lottery;

    address public owner = address(1);
    address public feeCollector = address(2);
    address public user1 = address(3);
    address public user2 = address(4);
    address public user3 = address(5);

    // Events to test
    event RoundStarted(uint256 indexed roundId, uint256 startTime, uint256 endTime);
    event TicketsPurchased(uint256 indexed roundId, address indexed buyer, uint256 numTickets, uint256 totalPaid);
    event DrawCommitted(uint256 indexed roundId, bytes32 commitHash, uint256 blockNumber);
    event WinnerSelected(uint256 indexed roundId, address indexed winner, uint256 prize);
    event PrizeClaimed(uint256 indexed roundId, address indexed winner, uint256 amount);
    event FeesCollected(address indexed collector, uint256 amount);

    function setUp() public {
        vm.prank(owner);
        lottery = new SimpleLottery(feeCollector);

        // Fund test users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR & INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(lottery.owner(), owner);
        assertEq(lottery.feeCollector(), feeCollector);
        assertEq(lottery.currentRoundId(), 1);
        assertEq(lottery.TICKET_PRICE(), 0.01 ether);
        assertEq(lottery.PLATFORM_FEE_PERCENT(), 10);
    }

    function test_Constructor_RevertsWithZeroFeeCollector() public {
        vm.prank(owner);
        vm.expectRevert(SimpleLottery.InvalidFeeCollector.selector);
        new SimpleLottery(address(0));
    }

    function test_FirstRoundStarted() public view {
        (
            uint256 roundId,
            uint256 startTime,
            uint256 endTime,
            uint256 totalTickets,
            uint256 prizePool,
            bool isActive
        ) = lottery.getCurrentRound();

        assertEq(roundId, 1);
        assertGt(startTime, 0);
        assertEq(endTime, startTime + 24 hours);
        assertEq(totalTickets, 0);
        assertEq(prizePool, 0);
        assertTrue(isActive);
    }

    /*//////////////////////////////////////////////////////////////
                        TICKET PURCHASING
    //////////////////////////////////////////////////////////////*/

    function test_EnterLottery_SingleTicket() public {
        vm.prank(user1);
        lottery.enterLottery{value: 0.01 ether}(1);

        assertEq(lottery.getUserTickets(1, user1), 1);

        (,,,uint256 totalTickets, uint256 prizePool,) = lottery.getCurrentRound();
        assertEq(totalTickets, 1);
        assertEq(prizePool, 0.01 ether);
    }

    function test_EnterLottery_MultipleTickets() public {
        vm.prank(user1);
        lottery.enterLottery{value: 0.05 ether}(5);

        assertEq(lottery.getUserTickets(1, user1), 5);

        (,,,uint256 totalTickets, uint256 prizePool,) = lottery.getCurrentRound();
        assertEq(totalTickets, 5);
        assertEq(prizePool, 0.05 ether);
    }

    function test_EnterLottery_MaxTickets() public {
        vm.prank(user1);
        lottery.enterLottery{value: 0.1 ether}(10);

        assertEq(lottery.getUserTickets(1, user1), 10);
    }

    function test_EnterLottery_MultipleUsers() public {
        vm.prank(user1);
        lottery.enterLottery{value: 0.02 ether}(2);

        vm.prank(user2);
        lottery.enterLottery{value: 0.03 ether}(3);

        vm.prank(user3);
        lottery.enterLottery{value: 0.01 ether}(1);

        assertEq(lottery.getUserTickets(1, user1), 2);
        assertEq(lottery.getUserTickets(1, user2), 3);
        assertEq(lottery.getUserTickets(1, user3), 1);

        (,,,uint256 totalTickets, uint256 prizePool,) = lottery.getCurrentRound();
        assertEq(totalTickets, 6);
        assertEq(prizePool, 0.06 ether);
    }

    function test_EnterLottery_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit TicketsPurchased(1, user1, 2, 0.02 ether);

        vm.prank(user1);
        lottery.enterLottery{value: 0.02 ether}(2);
    }

    function test_EnterLottery_RevertsWithZeroTickets() public {
        vm.prank(user1);
        vm.expectRevert(SimpleLottery.InvalidTicketCount.selector);
        lottery.enterLottery{value: 0.01 ether}(0);
    }

    function test_EnterLottery_RevertsWithTooManyTickets() public {
        vm.prank(user1);
        vm.expectRevert(SimpleLottery.InvalidTicketCount.selector);
        lottery.enterLottery{value: 0.11 ether}(11);
    }

    function test_EnterLottery_RevertsWithInvalidPayment() public {
        vm.prank(user1);
        vm.expectRevert(SimpleLottery.InvalidPayment.selector);
        lottery.enterLottery{value: 0.02 ether}(1); // Wrong amount
    }

    function test_EnterLottery_RevertsAfterRoundEnds() public {
        // Fast forward past round end
        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        vm.expectRevert(SimpleLottery.RoundNotActive.selector);
        lottery.enterLottery{value: 0.01 ether}(1);
    }

    function test_EnterLottery_RevertsWhenPaused() public {
        vm.prank(owner);
        lottery.pause();

        vm.prank(user1);
        vm.expectRevert();
        lottery.enterLottery{value: 0.01 ether}(1);
    }

    /*//////////////////////////////////////////////////////////////
                        COMMIT-REVEAL DRAW
    //////////////////////////////////////////////////////////////*/

    function test_CommitDraw_Success() public {
        // Users buy tickets
        vm.prank(user1);
        lottery.enterLottery{value: 0.03 ether}(3);

        // Fast forward past round end
        vm.warp(block.timestamp + 25 hours);

        // Owner commits to draw
        uint256 nonce = 12345;
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), nonce));

        vm.prank(owner);
        lottery.commitDraw(commitHash);

        SimpleLottery.Round memory round = lottery.getRound(1);
        assertEq(round.commitHash, commitHash);
        assertGt(round.commitBlock, 0);
    }

    function test_CommitDraw_RevertsBeforeRoundEnds() public {
        vm.prank(user1);
        lottery.enterLottery{value: 0.01 ether}(1);

        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), uint256(123)));

        vm.prank(owner);
        vm.expectRevert(SimpleLottery.RoundNotEnded.selector);
        lottery.commitDraw(commitHash);
    }

    function test_CommitDraw_RevertsWithNoTickets() public {
        // Fast forward without any tickets sold
        vm.warp(block.timestamp + 25 hours);

        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), uint256(123)));

        vm.prank(owner);
        vm.expectRevert(SimpleLottery.NoTicketsInRound.selector);
        lottery.commitDraw(commitHash);
    }

    function test_RevealDraw_SelectsWinner() public {
        // Users buy tickets
        vm.prank(user1);
        lottery.enterLottery{value: 0.02 ether}(2);

        vm.prank(user2);
        lottery.enterLottery{value: 0.03 ether}(3);

        // Fast forward past round end
        vm.warp(block.timestamp + 25 hours);

        // Commit draw
        uint256 nonce = 54321;
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), nonce));

        vm.prank(owner);
        lottery.commitDraw(commitHash);

        // Mine a few blocks
        vm.roll(block.number + 3);

        // Reveal draw
        vm.prank(owner);
        lottery.revealDraw(nonce);

        SimpleLottery.Round memory round = lottery.getRound(1);
        assertTrue(round.drawn);
        assertTrue(round.winner == user1 || round.winner == user2);
        assertEq(round.prizePool, 0.05 ether);
    }

    function test_RevealDraw_StartsNewRound() public {
        // Setup and complete round 1
        vm.prank(user1);
        lottery.enterLottery{value: 0.01 ether}(1);

        vm.warp(block.timestamp + 25 hours);

        uint256 nonce = 99999;
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), nonce));

        vm.prank(owner);
        lottery.commitDraw(commitHash);

        vm.roll(block.number + 3);

        vm.prank(owner);
        lottery.revealDraw(nonce);

        // Check new round started
        assertEq(lottery.currentRoundId(), 2);

        (uint256 roundId,,,,, bool isActive) = lottery.getCurrentRound();
        assertEq(roundId, 2);
        assertTrue(isActive);
    }

    function test_RevealDraw_RevertsWithoutCommit() public {
        vm.prank(user1);
        lottery.enterLottery{value: 0.01 ether}(1);

        vm.warp(block.timestamp + 25 hours);

        vm.prank(owner);
        vm.expectRevert(SimpleLottery.DrawNotCommitted.selector);
        lottery.revealDraw(123);
    }

    function test_RevealDraw_RevertsTooEarly() public {
        vm.prank(user1);
        lottery.enterLottery{value: 0.01 ether}(1);

        vm.warp(block.timestamp + 25 hours);

        uint256 nonce = 777;
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), nonce));

        vm.prank(owner);
        lottery.commitDraw(commitHash);

        // Try to reveal immediately (same block)
        vm.prank(owner);
        vm.expectRevert(SimpleLottery.TooEarlyToReveal.selector);
        lottery.revealDraw(nonce);
    }

    function test_RevealDraw_RevertsWithWrongNonce() public {
        vm.prank(user1);
        lottery.enterLottery{value: 0.01 ether}(1);

        vm.warp(block.timestamp + 25 hours);

        uint256 correctNonce = 111;
        uint256 wrongNonce = 222;
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), correctNonce));

        vm.prank (owner);
        lottery.commitDraw(commitHash);

        vm.roll(block.number + 3);

        vm.prank(owner);
        vm.expectRevert(SimpleLottery.InvalidReveal.selector);
        lottery.revealDraw(wrongNonce);
    }

    /*//////////////////////////////////////////////////////////////
                        PRIZE CLAIMING
    //////////////////////////////////////////////////////////////*/

    function test_ClaimPrize_Success() public {
        // Setup: User1 buys all tickets (guaranteed winner)
        vm.prank(user1);
        lottery.enterLottery{value: 0.05 ether}(5);

        // Complete draw
        vm.warp(block.timestamp + 25 hours);

        uint256 nonce = 555;
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), nonce));

        vm.prank(owner);
        lottery.commitDraw(commitHash);

        vm.roll(block.number + 3);

        vm.prank(owner);
        lottery.revealDraw(nonce);

        // Get winner and expected prize
        SimpleLottery.Round memory round = lottery.getRound(1);
        address winner = round.winner;
        uint256 expectedPrize = (0.05 ether * 90) / 100; // 90% of pool

        uint256 balanceBefore = winner.balance;

        // Winner claims prize
        vm.prank(winner);
        lottery.claimPrize(1);

        uint256 balanceAfter = winner.balance;
        assertEq(balanceAfter - balanceBefore, expectedPrize);

        // Check prize marked as claimed
        round = lottery.getRound(1);
        assertTrue(round.prizeClaimed);
    }

    function test_ClaimPrize_RevertsIfNotDrawn() public {
        vm.prank(user1);
        lottery.enterLottery{value: 0.01 ether}(1);

        vm.prank(user1);
        vm.expectRevert(SimpleLottery.RoundNotEnded.selector);
        lottery.claimPrize(1);
    }

    function test_ClaimPrize_RevertsIfNotWinner() public {
        vm.prank(user1);
        lottery.enterLottery{value: 0.01 ether}(1);

        vm.warp(block.timestamp + 25 hours);

        uint256 nonce = 333;
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), nonce));

        vm.prank(owner);
        lottery.commitDraw(commitHash);

        vm.roll(block.number + 3);

        vm.prank(owner);
        lottery.revealDraw(nonce);

        // User2 tries to claim (not winner)
        vm.prank(user2);
        vm.expectRevert(SimpleLottery.NotWinner.selector);
        lottery.claimPrize(1);
    }

    function test_ClaimPrize_RevertsIfAlreadyClaimed() public {
        vm.prank(user1);
        lottery.enterLottery{value: 0.01 ether}(1);

        vm.warp(block.timestamp + 25 hours);

        uint256 nonce = 444;
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), nonce));

        vm.prank(owner);
        lottery.commitDraw(commitHash);

        vm.roll(block.number + 3);

        vm.prank(owner);
        lottery.revealDraw(nonce);

        SimpleLottery.Round memory round = lottery.getRound(1);
        address winner = round.winner;

        // Claim once
        vm.prank(winner);
        lottery.claimPrize(1);

        // Try to claim again
        vm.prank(winner);
        vm.expectRevert(SimpleLottery.PrizeAlreadyClaimed.selector);
        lottery.claimPrize(1);
    }

    /*//////////////////////////////////////////////////////////////
                        FEE COLLECTION
    //////////////////////////////////////////////////////////////*/

    function test_CollectFees_Success() public {
        // Multiple users buy tickets
        vm.prank(user1);
        lottery.enterLottery{value: 0.05 ether}(5);

        // Complete draw and claim prize
        vm.warp(block.timestamp + 25 hours);

        uint256 nonce = 666;
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), nonce));

        vm.prank(owner);
        lottery.commitDraw(commitHash);

        vm.roll(block.number + 3);

        vm.prank(owner);
        lottery.revealDraw(nonce);

        SimpleLottery.Round memory round = lottery.getRound(1);
        vm.prank(round.winner);
        lottery.claimPrize(1);

        // Now collect fees
        uint256 expectedFees = (0.05 ether * 10) / 100; // 10% platform fee
        uint256 feeCollectorBalanceBefore = feeCollector.balance;

        vm.prank(owner);
        lottery.collectFees();

        uint256 feeCollectorBalanceAfter = feeCollector.balance;
        assertEq(feeCollectorBalanceAfter - feeCollectorBalanceBefore, expectedFees);
        assertEq(lottery.collectedFees(), 0);
    }

    function test_CollectFees_RevertsWithNoFees() public {
        vm.prank(owner);
        vm.expectRevert(SimpleLottery.NoFeesToCollect.selector);
        lottery.collectFees();
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_SetFeeCollector_Success() public {
        address newCollector = address(99);

        vm.prank(owner);
        lottery.setFeeCollector(newCollector);

        assertEq(lottery.feeCollector(), newCollector);
    }

    function test_SetFeeCollector_RevertsWithZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(SimpleLottery.InvalidFeeCollector.selector);
        lottery.setFeeCollector(address(0));
    }

    function test_SetFeeCollector_RevertsIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        lottery.setFeeCollector(address(99));
    }

    function test_Pause_Success() public {
        vm.prank(owner);
        lottery.pause();

        assertTrue(lottery.paused());
    }

    function test_Unpause_Success() public {
        vm.prank(owner);
        lottery.pause();

        vm.prank(owner);
        lottery.unpause();

        assertFalse(lottery.paused());
    }

    function test_Pause_RevertsIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        lottery.pause();
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_GetCurrentRound() public {
        (
            uint256 roundId,
            uint256 startTime,
            uint256 endTime,
            uint256 totalTickets,
            uint256 prizePool,
            bool isActive
        ) = lottery.getCurrentRound();

        assertEq(roundId, 1);
        assertGt(startTime, 0);
        assertGt(endTime, startTime);
        assertEq(totalTickets, 0);
assertEq(prizePool, 0);
        assertTrue(isActive);
    }

    function test_GetUserTickets() public {
        vm.prank(user1);
        lottery.enterLottery{value: 0.03 ether}(3);

        assertEq(lottery.getUserTickets(1, user1), 3);
        assertEq(lottery.getUserTickets(1, user2), 0);
    }

    function test_IsRoundActive() public view {
        assertTrue(lottery.isRoundActive());
    }

    function test_GetTimeRemaining() public {
        uint256 remaining = lottery.getTimeRemaining();
        assertGt(remaining, 0);
        assertLe(remaining, 24 hours);
    }

    function test_GetTimeRemaining_AfterRoundEnds() public {
        vm.warp(block.timestamp + 25 hours);

        assertEq(lottery.getTimeRemaining(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FullLotteryLifecycle() public {
        // Round 1: Multiple users buy tickets
        vm.prank(user1);
        lottery.enterLottery{value: 0.05 ether}(5);

        vm.prank(user2);
        lottery.enterLottery{value: 0.03 ether}(3);

        vm.prank(user3);
        lottery.enterLottery{value: 0.02 ether}(2);

        // Verify round state
        (,,,uint256 totalTickets1, uint256 prizePool1,) = lottery.getCurrentRound();
        assertEq(totalTickets1, 10);
        assertEq(prizePool1, 0.1 ether);

        // End round and draw
        vm.warp(block.timestamp + 25 hours);

        uint256 nonce = 11111;
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), nonce));

        vm.prank(owner);
        lottery.commitDraw(commitHash);

        vm.roll(block.number + 5);

        vm.prank(owner);
        lottery.revealDraw(nonce);

        // Get winner and verify they can claim
        SimpleLottery.Round memory round1 = lottery.getRound(1);
        assertTrue(round1.drawn);
        assertGt(uint160(round1.winner), 0);

        uint256 winnerBalanceBefore = round1.winner.balance;

        vm.prank(round1.winner);
        lottery.claimPrize(1);

        uint256 winnerBalanceAfter = round1.winner.balance;
        uint256 expectedPrize = (0.1 ether * 90) / 100;
        assertEq(winnerBalanceAfter - winnerBalanceBefore, expectedPrize);

        // Collect fees
        vm.prank(owner);
        lottery.collectFees();

        // Round 2 should be active
        assertEq(lottery.currentRoundId(), 2);
        assertTrue(lottery.isRoundActive());

        // Users can enter new round
        vm.prank(user1);
        lottery.enterLottery{value: 0.02 ether}(2);

        assertEq(lottery.getUserTickets(2, user1), 2);
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_EnterLottery(uint8 numTickets) public {
        // Bound to valid range
        numTickets = uint8(bound(numTickets, 1, 10));

        uint256 payment = uint256(numTickets) * 0.01 ether;
        vm.deal(user1, payment);

        vm.prank(user1);
        lottery.enterLottery{value: payment}(numTickets);

        assertEq(lottery.getUserTickets(1, user1), numTickets);
    }

    function testFuzz_CommitReveal(uint256 nonce) public {
        // Setup
        vm.prank(user1);
        lottery.enterLottery{value: 0.01 ether}(1);

        vm.warp(block.timestamp + 25 hours);

        // Commit
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), nonce));

        vm.prank(owner);
        lottery.commitDraw(commitHash);

        vm.roll(block.number + 3);

        // Reveal
        vm.prank(owner);
        lottery.revealDraw(nonce);

        SimpleLottery.Round memory round = lottery.getRound(1);
        assertTrue(round.drawn);
        assertEq(round.winner, user1); // Only one participant
    }
}
