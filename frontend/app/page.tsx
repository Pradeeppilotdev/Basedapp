'use client';

import { useLottery } from '../hooks/useLottery';
import { PrizePool } from '../components/PrizePool';
import { Countdown } from '../components/Countdown';
import { TicketPurchase } from '../components/TicketPurchase';
import { ConnectButton } from '@rainbow-me/rainbowkit';

export const dynamic = 'force-dynamic';

export default function Home() {
  const {
    currentRound,
    userTickets,
    timeRemaining,
    buyTickets,
    isEntering,
    isConfirming,
    isConfirmed,
    contractAddress,
    hasDeployedContract,
  } = useLottery();

  return (
    <div className="min-h-screen py-12 px-4">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <header className="mb-12 text-center">
          <h1 className="text-6xl font-bold text-white mb-4">
            🎰 Base Daily Lottery
          </h1>
          <p className="text-xl text-white/90 mb-6">
            Win ETH Every Day on Base Blockchain
          </p>
          <div className="flex justify-center">
            <ConnectButton />
          </div>
        </header>

        {/* Contract Warning */}
        {!hasDeployedContract && (
          <div className="mb-8 bg-yellow-100 border-2 border-yellow-400 rounded-lg p-6 text-center">
            <p className="text-yellow-900 font-semibold text-lg">
              ⚠️ Contract not deployed on this network yet
            </p>
            <p className="text-yellow-800 mt-2">
              Please switch to Base or Base Sepolia network
            </p>
          </div>
        )}

        {currentRound && (
          <>
            {/* Countdown */}
            <div className="mb-8">
              <Countdown timeRemaining={timeRemaining} />
            </div>

            {/* Main Grid */}
            <div className="grid md:grid-cols-2 gap-8 mb-8">
              {/* Prize Pool */}
              <PrizePool
                prizePool={currentRound.prizePool}
                totalTickets={currentRound.totalTickets}
              />

              {/* Ticket Purchase */}
              <TicketPurchase
                onBuyTickets={buyTickets}
                userTickets={userTickets}
                totalTickets={currentRound.totalTickets}
                isEntering={isEntering}
                isConfirming={isConfirming}
                isConfirmed={isConfirmed}
              />
            </div>

            {/* How It Works */}
            <div className="bg-white rounded-2xl shadow-2xl p-8">
              <h2 className="text-3xl font-bold text-gray-800 mb-6">How It Works</h2>
              <div className="grid md:grid-cols-3 gap-6">
                <HowItWorksCard
                  step="1"
                  title="Buy Tickets"
                  description="Purchase tickets for 0.01 ETH each. Buy up to 10 per transaction."
                  emoji="🎟️"
                />
                <HowItWorksCard
                  step="2"
                  title="Wait for Draw"
                  description="New lottery rounds happen every 24 hours. More tickets = more chances to win!"
                  emoji="⏰"
                />
                <HowItWorksCard
                  step="3"
                  title="Win Prizes"
                  description="Winner gets 90% of the prize pool. Check back to see if you won!"
                  emoji="🏆"
                />
              </div>
            </div>

            {/* Stats */}
            <div className="mt-8 grid md:grid-cols-3 gap-6">
              <StatCard label="Round" value={`#${currentRound.roundId}`} />
              <StatCard label="Your Tickets" value={userTickets.toString()} />
              <StatCard label="Status" value={currentRound.isActive ? '🟢 Active' : '🔴 Drawing'} />
            </div>
          </>
        )}

        {/* Footer */}
        <footer className="mt-12 text-center text-white/80 text-sm">
          <p>Built on Base • Powered by Smart Contracts • Provably Fair</p>
          {contractAddress && (
            <p className="mt-2">
              Contract: {contractAddress.slice(0, 6)}...{contractAddress.slice(-4)}
            </p>
          )}
        </footer>
      </div>
    </div>
  );
}

function HowItWorksCard({
  step,
  title,
  description,
  emoji,
}: {
  step: string;
  title: string;
  description: string;
  emoji: string;
}) {
  return (
    <div className="text-center">
      <div className="text-5xl mb-4">{emoji}</div>
      <div className="bg-purple-600 text-white rounded-full w-10 h-10 flex items-center justify-center mx-auto mb-3 font-bold">
        {step}
      </div>
      <h3 className="font-bold text-lg text-gray-800 mb-2">{title}</h3>
      <p className="text-gray-600 text-sm">{description}</p>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-white rounded-xl shadow-lg p-6 text-center">
      <div className="text-gray-600 text-sm mb-1">{label}</div>
      <div className="text-3xl font-bold text-purple-600">{value}</div>
    </div>
  );
}
