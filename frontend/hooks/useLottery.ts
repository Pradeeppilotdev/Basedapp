import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount, useChainId } from 'wagmi';
import { LOTTERY_ABI, LOTTERY_ADDRESS, isDeployedContractAddress } from '../lib/contracts';
import { parseEther } from 'viem';

export function useLottery() {
  const { address } = useAccount();
  const chainId = useChainId();
  const configuredAddress = LOTTERY_ADDRESS[chainId as keyof typeof LOTTERY_ADDRESS];
  const hasDeployedContract = isDeployedContractAddress(configuredAddress);
  const contractAddress = hasDeployedContract ? configuredAddress : undefined;

  // Read current round info
  const { data: currentRound, refetch: refetchRound } = useReadContract({
    address: contractAddress,
    abi: LOTTERY_ABI,
    functionName: 'getCurrentRound',
    query: {
      enabled: !!contractAddress,
      refetchInterval: 10000, // Refetch every 10 seconds
    },
  });

  // Read user's tickets for current round
  const { data: currentRoundId } = useReadContract({
    address: contractAddress,
    abi: LOTTERY_ABI,
    functionName: 'currentRoundId',
    query: {
      enabled: !!contractAddress,
    },
  });

  const { data: userTickets, refetch: refetchUserTickets } = useReadContract({
    address: contractAddress,
    abi: LOTTERY_ABI,
    functionName: 'getUserTickets',
    args: currentRoundId && address ? [currentRoundId, address] : undefined,
    query: {
      enabled: !!contractAddress && !!currentRoundId && !!address,
    },
  });

  // Read time remaining
  const { data: timeRemaining } = useReadContract({
    address: contractAddress,
    abi: LOTTERY_ABI,
    functionName: 'getTimeRemaining',
    query: {
      enabled: !!contractAddress,
      refetchInterval: 1000, // Update every second
    },
  });

  const { data: stats } = useReadContract({
    address: contractAddress,
    abi: LOTTERY_ABI,
    functionName: 'getStats',
    query: {
      enabled: !!contractAddress,
      refetchInterval: 10000,
    },
  });

  // Write: Enter lottery
  const { data: enterHash, writeContract: enterLottery, isPending: isEntering } = useWriteContract();

  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash: enterHash,
  });

  // Helper to buy tickets
  const buyTickets = async (numTickets: number) => {
    if (!contractAddress) throw new Error('Contract not deployed on this network');

    const value = parseEther((0.0001 * numTickets).toString());

    return enterLottery({
      address: contractAddress,
      abi: LOTTERY_ABI,
      functionName: 'enterLottery',
      args: [BigInt(numTickets)],
      value,
    });
  };

  // Parse round data
  const roundData = currentRound ? {
    roundId: Number(currentRound[0]),
    startTime: Number(currentRound[1]),
    endTime: Number(currentRound[2]),
    totalTickets: Number(currentRound[3]),
    prizePool: currentRound[4] as bigint,
    isActive: currentRound[5],
  } : null;

  const statsData = stats ? {
    totalTokensDistributed: stats[0] as bigint,
    totalParticipants: Number(stats[1]),
    treasuryBalance: stats[2] as bigint,
    liquidityCreated: stats[3] as boolean,
    liquidityPool: stats[4] as `0x${string}`,
  } : null;

  const treasuryThreshold = 100000000000000000n;
  const treasuryProgress = statsData?.treasuryBalance
    ? Math.min(100, Number((statsData.treasuryBalance * 10000n) / treasuryThreshold) / 100)
    : 0;

  return {
    // Data
    currentRound: roundData,
    userTickets: userTickets ? Number(userTickets) : 0,
    timeRemaining: timeRemaining ? Number(timeRemaining) : 0,
    treasuryProgress,
    stats: statsData,
    contractAddress,
    hasDeployedContract,

    // Actions
    buyTickets,
    refetchRound,
    refetchUserTickets,

    // Status
    isEntering,
    isConfirming,
    isConfirmed,
  };
}
