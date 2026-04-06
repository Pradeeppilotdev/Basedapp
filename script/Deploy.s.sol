// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HybridLottery} from "../src/HybridLottery.sol";
import {BasedToken} from "../src/BasedToken.sol";

/**
 * @title DeployHybridLottery
 * @notice Deployment script for HybridLottery and BasedToken contracts
 * @dev Deploy to Base Sepolia testnet or Base mainnet
 *
 * Usage:
 * 1. Copy .env.example to .env and fill in your values
 * 2. Deploy to Base Sepolia:
 *    forge script script/Deploy.s.sol:DeployHybridLottery --rpc-url base_sepolia --broadcast --verify
 * 3. Deploy to Base Mainnet:
 *    forge script script/Deploy.s.sol:DeployHybridLottery --rpc-url base --broadcast --verify
 */
contract DeployHybridLottery is Script {
    function run() external returns (HybridLottery, BasedToken) {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying Hybrid Lottery System...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy BasedToken - mints to deployer
        BasedToken token = new BasedToken(deployer);
        
        // Step 2: Deploy HybridLottery with token address
        HybridLottery lottery = new HybridLottery(address(token));
        
        // Step 3: Transfer all tokens to lottery
        token.transfer(address(lottery), token.totalSupply());

        vm.stopBroadcast();

        // Log deployment info
        console.log("\n===========================");
        console.log("DEPLOYMENT SUCCESSFUL");
        console.log("===========================");
        console.log("BasedToken deployed at:", address(token));
        console.log("HybridLottery deployed at:", address(lottery));
        console.log("===========================");

        // Token info
        console.log("\nToken Information:");
        console.log("  Name:", token.name());
        console.log("  Symbol:", token.symbol());
        console.log("  Total Supply:", token.totalSupply() / 10**18, "BASED");
        console.log("  Lottery Balance:", token.balanceOf(address(lottery)) / 10**18, "BASED");

        // Lottery info
        console.log("\nLottery Configuration:");
        console.log("  Ticket Price:", lottery.TICKET_PRICE(), "wei (0.0001 ETH)");
        console.log("  Winner Share:", lottery.WINNER_PERCENTAGE(), "%");
        console.log("  Treasury Share:", lottery.TREASURY_PERCENTAGE(), "%");
        console.log("  Tokens per Ticket:", lottery.TOKENS_PER_TICKET() / 10**18, "BASED");
        console.log("  Winner Bonus:", lottery.WINNER_BONUS_TOKENS() / 10**18, "BASED");

        // Treasury info
        console.log("\nTreasury & Liquidity:");
        console.log("  Liquidity Threshold:", lottery.LIQUIDITY_THRESHOLD(), "wei (0.1 ETH)");
        console.log("  Liquidity ETH Amount:", lottery.LIQUIDITY_ETH_AMOUNT(), "wei (0.05 ETH)");
        console.log("  Liquidity Token Amount:", lottery.LIQUIDITY_TOKEN_AMOUNT() / 10**18, "BASED");

        // Get round info
        (
            uint256 roundId,
            uint256 startTime,
            uint256 endTime,
            uint256 totalTickets,
            uint256 prizePool,
            bool isActive
        ) = lottery.getCurrentRound();

        console.log("\nCurrent Round:");
        console.log("  Round ID:", roundId);
        console.log("  Start Time:", startTime);
        console.log("  End Time:", endTime);
        console.log("  Total Tickets:", totalTickets);
        console.log("  Prize Pool:", prizePool);
        console.log("  Is Active:", isActive);

        // Stats
        (
            uint256 totalTokensDistributed,
            uint256 totalParticipants,
            uint256 treasuryBalance,
            bool liquidityCreated,
            address liquidityPool
        ) = lottery.getStats();

        console.log("\nStats:");
        console.log("  Tokens Distributed:", totalTokensDistributed / 10**18, "BASED");
        console.log("  Total Participants:", totalParticipants);
        console.log("  Treasury Balance:", treasuryBalance);
        console.log("  Liquidity Created:", liquidityCreated);

        console.log("\n===========================");
        console.log("NEXT STEPS");
        console.log("===========================");
        console.log("1. Save contract addresses:");
        console.log("   BasedToken:", address(token));
        console.log("   HybridLottery:", address(lottery));
        console.log("\n2. IMPORTANT: All tokens transferred to lottery");
        console.log("   Lottery is ready to distribute rewards!");
        console.log("\n3. Update frontend/lib/contracts.ts with addresses");
        console.log("\n4. Test on testnet:");
        console.log("   - Buy tickets (0.0001 ETH)");
        console.log("   - Verify token rewards received");
        console.log("   - Run a complete draw cycle");
        console.log("\n5. Monitor treasury until 0.1 ETH reached");
        console.log("\n6. Create Uniswap liquidity pool when ready");
        console.log("===========================\n");

        return (lottery, token);
    }
}

// Legacy deployment script for SimpleLottery (kept for reference)
contract DeploySimpleLottery is Script {
    function run() external {
        console.log("ERROR: Please use DeployHybridLottery instead");
        console.log("Run: forge script script/Deploy.s.sol:DeployHybridLottery ...");
        revert("Use DeployHybridLottery");
    }
}
