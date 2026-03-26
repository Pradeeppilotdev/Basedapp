// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {SimpleLottery} from "../src/SimpleLottery.sol";

/**
 * @title DeploySimpleLottery
 * @notice Deployment script for SimpleLottery contract
 * @dev Deploy to Base Sepolia testnet or Base mainnet
 *
 * Usage:
 * 1. Copy .env.example to .env and fill in your values
 * 2. Deploy to Base Sepolia:
 *    forge script script/Deploy.s.sol:DeploySimpleLottery --rpc-url base_sepolia --broadcast --verify
 * 3. Deploy to Base Mainnet:
 *    forge script script/Deploy.s.sol:DeploySimpleLottery --rpc-url base --broadcast --verify
 */
contract DeploySimpleLottery is Script {
    function run() external returns (SimpleLottery) {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying SimpleLottery...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        // Fee collector should be set to deployer initially
        // Can be changed later via setFeeCollector()
        address feeCollector = deployer;

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy SimpleLottery
        SimpleLottery lottery = new SimpleLottery(feeCollector);

        vm.stopBroadcast();

        // Log deployment info
        console.log("===========================");
        console.log("SimpleLottery deployed at:", address(lottery));
        console.log("Fee Collector:", lottery.feeCollector());
        console.log("Current Round ID:", lottery.currentRoundId());
        console.log("Ticket Price:", lottery.TICKET_PRICE());
        console.log("Platform Fee:", lottery.PLATFORM_FEE_PERCENT(), "%");
        console.log("===========================");

        // Get round info
        (
            uint256 roundId,
            uint256 startTime,
            uint256 endTime,
            ,
            ,
            bool isActive
        ) = lottery.getCurrentRound();

        console.log("\nCurrent Round:");
        console.log("  Round ID:", roundId);
        console.log("  Start Time:", startTime);
        console.log("  End Time:", endTime);
        console.log("  Is Active:", isActive);

        console.log("\nNext Steps:");
        console.log("1. Save contract address to .env");
        console.log("2. Verify on BaseScan (if not done automatically)");
        console.log("3. Test ticket purchase on testnet");
        console.log("4. Set up frontend with this contract address");

        return lottery;
    }
}
