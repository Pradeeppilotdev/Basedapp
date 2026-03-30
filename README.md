# 🎰 Base Daily Lottery - MVP

A decentralized daily lottery mini app built on Base blockchain. Users buy tickets, and a winner is selected every 24 hours to win 90% of the prize pool.

## 🎯 Project Overview

**MVP Features:**
- ✅ Single daily lottery pool (24-hour rounds)
- ✅ Fixed 0.01 ETH ticket price
- ✅ Users can buy 1-10 tickets per transaction
- ✅ Commit-reveal randomness (secure & cost-effective)
- ✅ 90% prize to winner, 10% platform fee
- ✅ Next.js frontend with Web3 wallet integration
- ✅ Real-time countdown and prize pool display

## 📦 Project Structure

```
basedapp/
├── src/              # Smart contract
│   └── SimpleLottery.sol
├── test/             # Contract tests (43 tests, all passing!)
│   └── SimpleLottery.t.sol
├── script/           # Deployment script
│   └── Deploy.s.sol
├── frontend/         # Next.js 14 app
│   ├── app/          # Pages
│   ├── components/   # UI components
│   ├── hooks/        # React hooks
│   └── lib/          # Configs & utilities
└── README.md
```

## 🚀 Quick Start

### Prerequisites

- Node.js 18+ and Yarn
- Foundry installed (`curl -L https://foundry.paradigm.xyz | bash; foundryup`)
- Base Sepolia testnet ETH
- WalletConnect Project ID from https://cloud.walletconnect.com/

### 1. Deploy Smart Contract

```bash
# Setup environment
cp .env.example .env
# Edit .env with your keys

# Install dependencies
forge install

# Run tests (all 43 should pass!)
~/.foundry/bin/forge test -vv

# Deploy to Base Sepolia
~/.foundry/bin/forge script script/Deploy.s.sol:DeploySimpleLottery \
  --rpc-url base_sepolia \
  --broadcast \
  --verify
```

### 2. Setup Frontend

```bash
cd frontend

# Install dependencies
yarn install

# Setup environment
cp .env.example .env.local
# Add your WalletConnect Project ID

# Update contract address in lib/contracts.ts
# (Use address from deployment step)

# Start dev server
yarn dev
```

Open http://localhost:3000 🎉

## 🎮 How It Works

1. **Buy Tickets** - Users purchase tickets for 0.01 ETH each
2. **24-Hour Rounds** - New lottery every day
3. **Fair Winner Selection** - Commit-reveal randomness ensures fairness
4. **90% to Winner** - Massive prize pool split, 10% platform fee
5. **Instant Claims** - Winners claim prizes anytime

## 📜 Smart Contract

**SimpleLottery.sol** - Main contract with:
- Ticket purchasing
- Commit-reveal draw mechanism
- Prize claiming
- Admin functions
- Emergency pause
- And a Flow
**Security:**
- OpenZeppelin contracts (Ownable, ReentrancyGuard, Pausable)
- Pull-over-push payments
- Comprehensive test coverage (>90%)
- 43/43 tests passing

## 🎨 Frontend

**Built with:**
- Next.js 14 (App Router)
- TypeScript
- Wagmi v2 & Viem v2 (Web3)
- RainbowKit (Wallets)
- TailwindCSS
- 

**Features:**
- Real-time prize pool updates
- Live countdown timer
- Wallet connection
- Transaction status feedback
- Responsive design

## 🔧 Admin: Running Draws

For MVP, draws are manual. See full instructions in contract comments.

**Quick version:**

```bash
# 1. Commit draw (after 24h)
cast send $CONTRACT "commitDraw(bytes32)" $HASH --rpc-url base_sepolia --private-key $KEY

# 2. Wait 2+ blocks

# 3. Reveal winner
cast send $CONTRACT "revealDraw(uint256)" $NONCE --rpc-url base_sepolia --private-key $KEY
```

## 📊 Test Results

```
Ran 43 tests for SimpleLottery
✅ All tests passed
✅ Fuzz tests included
✅ >90% coverage
```

## 🚧 Next Steps

**To Launch:**
1. Deploy contract to Base Sepolia ✅
2. Test with real wallets on testnet
3. Add Farcaster mini app manifest
4. Create automated draw script
5. Security review
6. Deploy to Base mainnet

**Phase 2 Features:**
- Multiple pool types (hourly, weekly)
- Referral system
- Streak tracking
- Leaderboards
- Chainlink VRF upgrade

## 📝 Development

```bash
# Smart contracts
forge build          # Compile
forge test -vvv      # Test with traces
forge coverage       # Coverage report

# Frontend
cd frontend
yarn dev            # Dev server
yarn build          # Production build
yarn lint           # Lint check
```

## ⚠️ Disclaimer

Experimental software. Use at your own risk. Not financial advice. Check local regulations regarding lotteries.

## 📞 Questions?

Open an issue on GitHub or check the detailed documentation in the code.

---

**Built on Base 🔵 • Provably Fair 🎲 • Open Source 💙**
