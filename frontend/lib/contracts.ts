import { Address } from 'viem';

// Contract addresses - UPDATE after deployment!
export const LOTTERY_ADDRESS: Record<number, Address> = {
  // Base Sepolia testnet
  84532: '0x0000000000000000000000000000000000000000', // Replace after deploying to Sepolia
  // Base mainnet
  8453: '0x0000000000000000000000000000000000000000', // Replace after deploying to mainnet
};

// SimpleLottery ABI (only the functions we need)
export const LOTTERY_ABI = [
  // Constants
  {
    inputs: [],
    name: 'TICKET_PRICE',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'PLATFORM_FEE_PERCENT',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  // State variables
  {
    inputs: [],
    name: 'currentRoundId',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  // User functions
  {
    inputs: [{ internalType: 'uint256', name: '_numTickets', type: 'uint256' }],
    name: 'enterLottery',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'uint256', name: '_roundId', type: 'uint256' }],
    name: 'claimPrize',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  // View functions
  {
    inputs: [],
    name: 'getCurrentRound',
    outputs: [
      { internalType: 'uint256', name: 'roundId', type: 'uint256' },
      { internalType: 'uint256', name: 'startTime', type: 'uint256' },
      { internalType: 'uint256', name: 'end Time', type: 'uint256' },
      { internalType: 'uint256', name: 'totalTickets', type: 'uint256' },
      { internalType: 'uint256', name: 'prizePool', type: 'uint256' },
      { internalType: 'bool', name: 'isActive', type: 'bool' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'uint256', name: '_roundId', type: 'uint256' },
      { internalType: 'address', name: '_user', type: 'address' },
    ],
    name: 'getUserTickets',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'uint256', name: '_roundId', type: 'uint256' }],
    name: 'getRound',
    outputs: [
      {
        components: [
          { internalType: 'uint256', name: 'roundId', type: 'uint256' },
          { internalType: 'uint256', name: 'startTime', type: 'uint256' },
          { internalType: 'uint256', name: 'endTime', type: 'uint256' },
          { internalType: 'uint256', name: 'totalTickets', type: 'uint256' },
          { internalType: 'uint256', name: 'prizePool', type: 'uint256' },
          { internalType: 'address', name: 'winner', type: 'address' },
          { internalType: 'bool', name: 'drawn', type: 'bool' },
          { internalType: 'bool', name: 'prizeClaimed', type: 'bool' },
          { internalType: 'bytes32', name: 'commitHash', type: 'bytes32' },
          { internalType: 'uint256', name: 'commitBlock', type: 'uint256' },
        ],
        internalType: 'struct SimpleLottery.Round',
        name: '',
        type: 'tuple',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getTimeRemaining',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  // Events
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'uint256', name: 'roundId', type: 'uint256' },
      { indexed: true, internalType: 'address', name: 'buyer', type: 'address' },
      { indexed: false, internalType: 'uint256', name: 'numTickets', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'totalPaid', type: 'uint256' },
    ],
    name: 'TicketsPurchased',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'uint256', name: 'roundId', type: 'uint256' },
      { indexed: true, internalType: 'address', name: 'winner', type: 'address' },
      { indexed: false, internalType: 'uint256', name: 'prize', type: 'uint256' },
    ],
    name: 'WinnerSelected',
    type: 'event',
  },
] as const;
