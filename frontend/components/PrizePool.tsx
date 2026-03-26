'use client';

interface PrizePoolProps {
  prizePool: string;
  totalTickets: number;
}

export function PrizePool({ prizePool, totalTickets }: PrizePoolProps) {
  return (
    <div className="bg-white rounded-2xl shadow-2xl p-8 text-center">
      <h2 className="text-2xl font-bold text-gray-800 mb-4">Current Prize Pool</h2>
      <div className="mb-6">
        <div className="text-6xl font-bold text-purple-600 mb-2">
          {prizePool} ETH
        </div>
        <p className="text-gray-600">
          {totalTickets} {totalTickets === 1 ? 'ticket' : 'tickets'} sold
        </p>
      </div>
      <div className="bg-purple-50 rounded-lg p-4">
        <p className="text-sm text-gray-700">
          🏆 Winner gets <span className="font-bold text-purple-600">90%</span> of prize pool
        </p>
      </div>
    </div>
  );
}
