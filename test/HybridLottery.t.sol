// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {HybridLottery} from "../src/HybridLottery.sol";
import {BasedToken} from "../src/BasedToken.sol";

contract HybridLotteryTest is Test {
    HybridLottery public lottery;
    BasedToken public token;

    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);

    uint256 constant TICKET_PRICE = 0.0001 ether;
    uint256 constant TOKENS_PER_TICKET = 100 * 10**18;
    uint256 constant WINNER_BONUS = 10_000 * 10**18;

    event TicketsPurchased(
        uint256 indexed roundId, 
        address indexed buyer, 
        uint256 numTickets, 
        uint256 ethPaid,
        uint256 tokensReceived
    );
    event WinnerSelected(
        uint256 indexed roundId, 
        address indexed winner, 
        uint256 ethPrize,
        uint256 tokenBonus
    );
    event PrizeClaimed(uint256 indexed roundId, address indexed winner, uint256 ethAmount, uint256 tokenAmount);

    function setUp() public {
        // NOW we can deploy in the right order!
        
        // Step 1: Deploy token - mints to test contract (owner)
        token = new BasedToken(address(this));
        
        // Step 2: Deploy lottery with correct token address
        lottery = new HybridLottery(address(token));
        
        // Step 3: Transfer all tokens to lottery
        token.transfer(address(lottery), token.totalSupply());

        // Verify everything matches
        assertEq(address(lottery.basedToken()), address(token), "Lottery token mismatch");
        assertEq(token.balanceOf(address(lottery)), 1_000_000_000 * 10**18, "Lottery should have all tokens");

        // Fund test users
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                           DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Deployment() public view {
        assertEq(lottery.TICKET_PRICE(), TICKET_PRICE);
        assertEq(lottery.WINNER_PERCENTAGE(), 80);
        assertEq(lottery.TREASURY_PERCENTAGE(), 20);
        assertEq(lottery.currentRoundId(), 1);
        assertEq(lottery.treasuryBalance(), 0);
        assertFalse(lottery.liquidityCreated());
    }

    function test_TokenDeployment() public view {
        assertEq(token.name(), "Based Token");
        assertEq(token.symbol(), "BASED");
        assertEq(token.totalSupply(), 1_000_000_000 * 10**18);
        assertEq(token.balanceOf(address(lottery)), 1_000_000_000 * 10**18);
    }

    /*//////////////////////////////////////////////////////////////
                         TICKET PURCHASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BuyOneTicket() public {
        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE}(1);

        assertEq(lottery.userTickets(1, user1), 1);
        assertEq(token.balanceOf(user1), TOKENS_PER_TICKET);
        
        (,,, uint256 totalTickets, uint256 prizePool,) = lottery.getCurrentRound();
        assertEq(totalTickets, 1);
        assertEq(prizePool, TICKET_PRICE * 80 / 100); // 80% to prize
        assertEq(lottery.treasuryBalance(), TICKET_PRICE * 20 / 100); // 20% to treasury
    }

    function test_BuyMultipleTickets() public {
        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE * 5}(5);

        assertEq(lottery.userTickets(1, user1), 5);
        assertEq(token.balanceOf(user1), TOKENS_PER_TICKET * 5);
    }

    function test_BuyMaxTickets() public {
        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE * 10}(10);

        assertEq(lottery.userTickets(1, user1), 10);
        assertEq(token.balanceOf(user1), TOKENS_PER_TICKET * 10);
    }

    function test_RevertInvalidTicketCount() public {
        vm.prank(user1);
        vm.expectRevert(HybridLottery.InvalidTicketCount.selector);
        lottery.enterLottery{value: TICKET_PRICE}(0);

        vm.prank(user1);
        vm.expectRevert(HybridLottery.InvalidTicketCount.selector);
        lottery.enterLottery{value: TICKET_PRICE * 11}(11);
    }

    function test_RevertInvalidPayment() public {
        vm.prank(user1);
        vm.expectRevert(HybridLottery.InvalidPayment.selector);
        lottery.enterLottery{value: TICKET_PRICE * 2}(1);
    }

    function test_MultipleBuyers() public {
        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE * 3}(3);

        vm.prank(user2);
        lottery.enterLottery{value: TICKET_PRICE * 2}(2);

        vm.prank(user3);
        lottery.enterLottery{value: TICKET_PRICE}(1);

        assertEq(lottery.userTickets(1, user1), 3);
        assertEq(lottery.userTickets(1, user2), 2);
        assertEq(lottery.userTickets(1, user3), 1);

        (,,, uint256 totalTickets,,) = lottery.getCurrentRound();
        assertEq(totalTickets, 6);
    }

    function test_EmitTicketsPurchased() public {
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit TicketsPurchased(1, user1, 2, TICKET_PRICE * 2, TOKENS_PER_TICKET * 2);
        lottery.enterLottery{value: TICKET_PRICE * 2}(2);
    }

    /*//////////////////////////////////////////////////////////////
                            DRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CommitAndRevealDraw() public {
        // Users buy tickets
        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE * 3}(3);

        vm.prank(user2);
        lottery.enterLottery{value: TICKET_PRICE * 2}(2);

        // Fast forward past round end
        vm.warp(block.timestamp + 24 hours + 1);

        // Commit draw
        uint256 nonce = 12345;
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), nonce));
        lottery.commitDraw(commitHash);

        // Wait required blocks
        vm.roll(block.number + 2);

        // Reveal and select winner
        lottery.revealDraw(nonce);

        HybridLottery.Round memory round = lottery.getRound(1);
        assertTrue(round.drawn);
        assertTrue(round.winner == user1 || round.winner == user2);
    }

    function test_RevertDrawBeforeRoundEnd() public {
        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE}(1);

        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), uint256(123)));
        vm.expectRevert(HybridLottery.RoundNotEnded.selector);
        lottery.commitDraw(commitHash);
    }

    function test_RevertDrawWithNoTickets() public {
        vm.warp(block.timestamp + 24 hours + 1);

        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), uint256(123)));
        vm.expectRevert(HybridLottery.NoTicketsInRound.selector);
        lottery.commitDraw(commitHash);
    }

    function test_RevertRevealTooEarly() public {
        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE}(1);

        vm.warp(block.timestamp + 24 hours + 1);

        uint256 nonce = 123;
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), nonce));
        lottery.commitDraw(commitHash);

        // Try to reveal immediately
        vm.expectRevert(HybridLottery.TooEarlyToReveal.selector);
        lottery.revealDraw(nonce);
    }

    function test_RevertInvalidReveal() public {
        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE}(1);

        vm.warp(block.timestamp + 24 hours + 1);

        uint256 nonce = 123;
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), nonce));
        lottery.commitDraw(commitHash);

        vm.roll(block.number + 2);

        // Try to reveal with wrong nonce
        vm.expectRevert(HybridLottery.InvalidReveal.selector);
        lottery.revealDraw(456);
    }

    /*//////////////////////////////////////////////////////////////
                          PRIZE CLAIM TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ClaimPrize() public {
        // Buy tickets
        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE * 5}(5);

        // Complete draw
        vm.warp(block.timestamp + 24 hours + 1);
        uint256 nonce = 12345;
        bytes32 commitHash = keccak256(abi.encodePacked(uint256(1), nonce));
        lottery.commitDraw(commitHash);
        vm.roll(block.number + 2);
        lottery.revealDraw(nonce);

        HybridLottery.Round memory round = lottery.getRound(1);
        address winner = round.winner;

        uint256 balanceBefore = winner.balance;
        uint256 tokenBalanceBefore = token.balanceOf(winner);

        // Claim prize
        vm.prank(winner);
        lottery.claimPrize(1);

        // Check ETH prize (80% of pool)
        assertEq(winner.balance, balanceBefore + round.prizePool);
        
        // Check token bonus
        assertEq(token.balanceOf(winner), tokenBalanceBefore + WINNER_BONUS);

        // Check prize marked as claimed
        round = lottery.getRound(1);
        assertTrue(round.prizeClaimed);
    }

    function test_RevertClaimByNonWinner() public {
        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE}(1);

        vm.warp(block.timestamp + 24 hours + 1);
        uint256 nonce = 123;
        lottery.commitDraw(keccak256(abi.encodePacked(uint256(1), nonce)));
        vm.roll(block.number + 2);
        lottery.revealDraw(nonce);

        vm.prank(user2);
        vm.expectRevert(HybridLottery.NotWinner.selector);
        lottery.claimPrize(1);
    }

    function test_RevertDoubleClaimPrize() public {
        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE}(1);

        vm.warp(block.timestamp + 24 hours + 1);
        uint256 nonce = 123;
        lottery.commitDraw(keccak256(abi.encodePacked(uint256(1), nonce)));
        vm.roll(block.number + 2);
        lottery.revealDraw(nonce);

        address winner = lottery.getRound(1).winner;

        vm.startPrank(winner);
        lottery.claimPrize(1);

        vm.expectRevert(HybridLottery.PrizeAlreadyClaimed.selector);
        lottery.claimPrize(1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                         TREASURY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TreasuryAccumulation() public {
        // Each ticket: 0.0001 ETH, 20% to treasury = 0.00002 ETH

        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE * 10}(10);

        assertEq(lottery.treasuryBalance(), TICKET_PRICE * 10 * 20 / 100);

        // Complete round and start new one
        vm.warp(block.timestamp + 24 hours + 1);
        lottery.commitDraw(keccak256(abi.encodePacked(uint256(1), uint256(123))));
        vm.roll(block.number + 2);
        lottery.revealDraw(123);

        // Buy in new round
        vm.prank(user2);
        lottery.enterLottery{value: TICKET_PRICE * 10}(10);

        assertEq(lottery.treasuryBalance(), TICKET_PRICE * 20 * 20 / 100);
    }

    function test_CanCreateLiquidity() public {
        assertFalse(lottery.canCreateLiquidity());

        // Need 0.1 ETH in treasury
        // Each ticket: 0.0001 ETH, 20% to treasury = 0.00002 ETH per ticket
        // Tickets needed: 0.1 / 0.00002 = 5000 tickets
        uint256 ticketsNeeded = 5000;
        
        // Buy tickets in batches of 10
        for (uint256 i = 0; i < ticketsNeeded / 10; i++) {
            vm.prank(user1);
            lottery.enterLottery{value: TICKET_PRICE * 10}(10);
        }

        assertTrue(lottery.canCreateLiquidity());
    }

    /*//////////////////////////////////////////////////////////////
                          STATS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Stats() public {
        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE * 3}(3);

        vm.prank(user2);
        lottery.enterLottery{value: TICKET_PRICE * 2}(2);

        (
            uint256 totalTokens,
            uint256 totalParticipants,
            uint256 treasury,
            bool liquidityCreated,
        ) = lottery.getStats();

        assertEq(totalTokens, TOKENS_PER_TICKET * 5);
        assertEq(totalParticipants, 2);
        assertEq(treasury, TICKET_PRICE * 5 * 20 / 100);
        assertFalse(liquidityCreated);
    }

    /*//////////////////////////////////////////////////////////////
                          PAUSE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PauseUnpause() public {
        lottery.pause();
        assertTrue(lottery.paused());

        vm.prank(user1);
        vm.expectRevert();
        lottery.enterLottery{value: TICKET_PRICE}(1);

        lottery.unpause();
        assertFalse(lottery.paused());

        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE}(1);
    }

    /*//////////////////////////////////////////////////////////////
                       MULTIPLE ROUNDS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MultipleRounds() public {
        // Round 1
        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE * 2}(2);

        vm.warp(block.timestamp + 24 hours + 1);
        lottery.commitDraw(keccak256(abi.encodePacked(uint256(1), uint256(111))));
        vm.roll(block.number + 2);
        lottery.revealDraw(111);

        assertEq(lottery.currentRoundId(), 2);

        // Round 2
        vm.prank(user2);
        lottery.enterLottery{value: TICKET_PRICE * 3}(3);

        assertEq(lottery.userTickets(2, user2), 3);
        assertEq(lottery.userTickets(1, user2), 0); // Different round
    }

    /*//////////////////////////////////////////////////////////////
                         FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_BuyTickets(uint256 numTickets) public {
        numTickets = bound(numTickets, 1, 10);

        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE * numTickets}(numTickets);

        assertEq(lottery.userTickets(1, user1), numTickets);
        assertEq(token.balanceOf(user1), TOKENS_PER_TICKET * numTickets);
    }

    function testFuzz_TreasuryPercentage(uint256 numTickets) public {
        numTickets = bound(numTickets, 1, 10);

        vm.prank(user1);
        lottery.enterLottery{value: TICKET_PRICE * numTickets}(numTickets);

        uint256 expectedTreasury = TICKET_PRICE * numTickets * 20 / 100;
        assertEq(lottery.treasuryBalance(), expectedTreasury);
    }
}
