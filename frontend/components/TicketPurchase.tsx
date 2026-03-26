'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';

interface TicketPurchaseProps {
  onBuyTickets: (numTickets: number) => Promise<void>;
  userTickets: number;
  isEntering: boolean;
  isConfirming: boolean;
  isConfirmed: boolean;
}

export function TicketPurchase({
  onBuyTickets,
  userTickets,
  isEntering,
  isConfirming,
  isConfirmed,
}: TicketPurchaseProps) {
  const { isConnected } = useAccount();
  const [numTickets, setNumTickets] = useState(1);
  const [error, setError] = useState('');

  const handleBuy = async () => {
    setError('');
    try {
      await onBuyTickets(numTickets);
    } catch (err: any) {
      setError(err.message || 'Failed to buy tickets');
    }
  };

  const totalCost = (0.01 * numTickets).toFixed(3);

  return (
    <div className="bg-white rounded-2xl shadow-2xl p-8">
      <h2 className="text-3xl font-bold text-gray-800 mb-6">Buy Lottery Tickets</h2>

      {userTickets > 0 && (
        <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
          <p className="text-green-800 font-medium">
            🎟️ You own {userTickets} {userTickets === 1 ? 'ticket' : 'tickets'} in this round!
          </p>
        </div>
      )}

      {!isConnected ? (
        <div className="flex flex-col items-center py-8">
          <p className="text-gray-600 mb-4">Connect your wallet to play</p>
          <ConnectButton />
        </div>
      ) : (
        <>
          <div className="mb-6">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Number of Tickets (0.01 ETH each)
            </label>
            <div className="flex items-center gap-4">
              <button
                onClick={() => setNumTickets(Math.max(1, numTickets - 1))}
                className="bg-gray-200 hover:bg-gray-300 text-gray-800 font-bold py-3 px-6 rounded-lg transition"
                disabled={isEntering || isConfirming}
              >
                -
              </button>
              <div className="flex-1 text-center">
                <div className="text-4xl font-bold text-purple-600">{numTickets}</div>
                <div className="text-sm text-gray-600 mt-1">
                  {numTickets === 10 && '(Maximum)'}
                </div>
              </div>
              <button
                onClick={() => setNumTickets(Math.min(10, numTickets + 1))}
                className="bg-gray-200 hover:bg-gray-300 text-gray-800 font-bold py-3 px-6 rounded-lg transition"
                disabled={isEntering || isConfirming}
              >
                +
              </button>
            </div>
          </div>

          <div className="bg-purple-50 rounded-lg p-4 mb-6">
            <div className="flex justify-between text-sm mb-2">
              <span className="text-gray-700">Tickets ({numTickets})</span>
              <span className="font-medium">{totalCost} ETH</span>
            </div>
            <div className="flex justify-between text-sm text-gray-600">
              <span>Your win chance</span>
              <span className="font-medium">Coming soon</span>
            </div>
          </div>

          <button
            onClick={handleBuy}
            disabled={isEntering || isConfirming}
            className="w-full bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-700 hover:to-indigo-700 text-white font-bold py-4 px-6 rounded-lg transition shadow-lg disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isEntering && 'Waiting for approval...'}
            {isConfirming && 'Confirming transaction...'}
            {isConfirmed && '✓ Tickets purchased!'}
            {!isEntering && !isConfirming && !isConfirmed && `Buy ${numTickets} ${numTickets === 1 ? 'Ticket' : 'Tickets'} for ${totalCost} ETH`}
          </button>

          {error && (
            <div className="mt-4 bg-red-50 border border-red-200 rounded-lg p-3">
              <p className="text-red-800 text-sm">{error}</p>
            </div>
          )}

          {isConfirmed && (
            <div className="mt-4 bg-green-50 border border-green-200 rounded-lg p-3">
              <p className="text-green-800 text-sm font-medium">
                Success! Your tickets have been purchased. Good luck! 🍀
              </p>
            </div>
          )}
        </>
      )}
    </div>
  );
}
