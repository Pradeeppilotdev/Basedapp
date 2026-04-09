'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { Coins, Trophy, Users, TrendingUp, Sparkles, Clock } from "lucide-react";

export default function LotteryDashboard() {
  // Mock data - will be replaced with real contract data
  const stats = {
    currentPrize: "0.0042",
    participants: 52,
    yourTickets: 3,
    yourTokens: 300,
    timeLeft: "18:42:15",
    treasuryProgress: 42, // % towards 0.1 ETH
    tokenDistributed: "52,000",
  };

  return (
    <div className="min-h-screen p-4 md:p-8 space-y-8">
      {/* Hero Section */}
      <div className="max-w-6xl mx-auto text-center space-y-4 pt-8">
        <Badge className="mb-4 text-sm px-4 py-1.5 animate-pulse-glow">
          <Sparkles className="w-3 h-3 mr-1.5" />
          Live Now - Round #42
        </Badge>
        
        <h1 className="text-5xl md:text-7xl font-bold tracking-tight">
          <span className="text-gradient">Based Daily Lottery</span>
        </h1>
        
        <p className="text-slate-400 text-lg md:text-xl max-w-2xl mx-auto">
          Enter for just <span className="text-cyan-400 font-bold">$0.30</span>, 
          win <span className="text-purple-400 font-bold">ETH + 10k tokens</span>, 
          everyone gets rewards 🎲
        </p>
      </div>

      {/* Main Stats Grid */}
      <div className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Prize Pool Card */}
        <Card className="md:col-span-2 border-2 border-purple-500/30 hover:border-purple-500/50 transition-all hover:glow-purple">
          <CardHeader>
            <div className="flex items-center justify-between">
              <div>
                <CardDescription>Total Prize Pool</CardDescription>
                <CardTitle className="text-5xl mt-2 flex items-baseline gap-2">
                  <Trophy className="w-10 h-10 text-yellow-500 animate-float" />
                  <span className="text-gradient">{stats.currentPrize}</span>
                  <span className="text-2xl text-slate-400">ETH</span>
                </CardTitle>
              </div>
              <Badge variant="success" className="text-base px-4 py-2">
                +10,000 BASED
              </Badge>
            </div>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 gap-4 pt-4">
              <div className="space-y-1">
                <p className="text-sm text-slate-400">Winner Gets (80%)</p>
                <p className="text-2xl font-bold text-gradient">{(parseFloat(stats.currentPrize) * 0.8).toFixed(4)} ETH</p>
              </div>
              <div className="space-y-1">
                <p className="text-sm text-slate-400">Treasury (20%)</p>
                <p className="text-2xl font-bold text-cyan-400">{(parseFloat(stats.currentPrize) * 0.2).toFixed(4)} ETH</p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Countdown Card */}
        <Card className="border-2 border-cyan-500/30 hover:border-cyan-500/50 transition-all hover:glow-cyan">
          <CardHeader>
            <CardDescription>Draw In</CardDescription>
            <CardTitle className="text-4xl mt-2 font-mono">
              <Clock className="w-8 h-8 inline-block mr-2 text-cyan-500" />
              <span className="text-gradient">{stats.timeLeft}</span>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3 pt-4">
              <div className="flex items-center justify-between text-sm">
                <span className="text-slate-400 flex items-center gap-2">
                  <Users className="w-4 h-4" />
                  Participants
                </span>
                <span className="font-bold text-purple-400">{stats.participants}</span>
              </div>
              <div className="flex items-center justify-between text-sm">
                <span className="text-slate-400 flex items-center gap-2">
                  <Coins className="w-4 h-4" />
                  Your Tickets
                </span>
                <span className="font-bold text-cyan-400">{stats.yourTickets}</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Purchase Section */}
      <div className="max-w-6xl mx-auto">
        <Card className="border-2 border-purple-500/30">
          <CardHeader>
            <CardTitle className="text-2xl">Enter the Lottery</CardTitle>
            <CardDescription>
              Buy 1-10 tickets • Get 100 BASED tokens per ticket instantly
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            {/* Ticket Selector */}
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <label className="text-sm font-medium text-slate-300">Number of Tickets</label>
                <Badge variant="secondary">0.0001 ETH each</Badge>
              </div>
              
              <div className="grid grid-cols-5 gap-2">
                {[1, 2, 3, 5, 10].map((num) => (
                  <Button
                    key={num}
                    variant="outline"
                    className="h-16 text-xl font-bold hover:scale-105 transition-transform"
                  >
                    {num}
                  </Button>
                ))}
              </div>

              {/* Purchase Summary */}
              <div className="bg-slate-900/50 rounded-lg p-4 space-y-2 border border-purple-500/20">
                <div className="flex justify-between text-sm">
                  <span className="text-slate-400">Cost</span>
                  <span className="font-mono text-slate-200">0.0003 ETH ($0.90)</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-slate-400">Instant Reward</span>
                  <span className="font-bold text-purple-400">300 BASED tokens</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-slate-400">Potential Win</span>
                  <span className="font-bold text-cyan-400">{(parseFloat(stats.currentPrize) * 0.8).toFixed(4)} ETH + 10k BASED</span>
                </div>
              </div>

              <Button size="lg" className="w-full text-lg h-14 shadow-2xl hover:scale-[1.02] transition-transform">
                <Sparkles className="w-5 h-5 mr-2" />
                Buy 3 Tickets
                <Sparkles className="w-5 h-5 ml-2" />
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Token Stats */}
      <div className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Your Tokens */}
        <Card>
          <CardHeader>
            <CardDescription>Your Token Balance</CardDescription>
            <CardTitle className="text-3xl">
              <Coins className="w-7 h-7 inline-block mr-2 text-purple-500" />
              <span className="text-gradient">{stats.yourTokens}</span>
              <span className="text-xl text-slate-400 ml-2">BASED</span>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              <div className="flex items-center justify-between text-sm">
                <span className="text-slate-400">Total Distributed</span>
                <span className="font-bold text-purple-400">{stats.tokenDistributed}</span>
              </div>
              <Button variant="secondary" className="w-full" size="sm">
                <TrendingUp className="w-4 h-4 mr-2" />
                Trade on Uniswap (Soon)
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Treasury Progress */}
        <Card>
          <CardHeader>
            <CardDescription>Liquidity Fund Progress</CardDescription>
            <CardTitle className="text-3xl">
              <span className="text-gradient">{stats.treasuryProgress}%</span>
              <span className="text-xl text-slate-400 ml-2">to 0.1 ETH</span>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              <Progress value={stats.treasuryProgress} className="h-3" />
              <p className="text-xs text-slate-400">
                Once we reach 0.1 ETH, a Uniswap liquidity pool will be created making BASED tokens tradeable! 🚀
              </p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* How It Works */}
      <div className="max-w-6xl mx-auto">
        <Card className="border-purple-500/20">
          <CardHeader>
            <CardTitle>How It Works</CardTitle>
            <CardDescription>Simple, fair, and transparent</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
              {[
                { icon: "🎫", title: "Buy Tickets", desc: "0.0001 ETH each" },
                { icon: "🪙", title: "Get Tokens", desc: "100 BASED instantly" },
                { icon: "⏰", title: "Wait 24h", desc: "Daily draws" },
                { icon: "🏆", title: "Win Big", desc: "80% ETH + 10k tokens" },
              ].map((step, i) => (
                <div key={i} className="text-center space-y-2 p-4 rounded-lg bg-slate-900/30 border border-purple-500/10 hover:border-purple-500/30 transition-colors">
                  <div className="text-4xl">{step.icon}</div>
                  <h3 className="font-bold text-purple-300">{step.title}</h3>
                  <p className="text-sm text-slate-400">{step.desc}</p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
