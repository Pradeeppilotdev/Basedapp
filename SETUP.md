# Setup & Deployment Guide

## Current Status ✅
- Frontend running successfully at http://localhost:3000
- All dependencies resolved
- No build errors or TypeScript issues
- Ready for development and deployment

## Environment Setup

### 1. Get WalletConnect Project ID
```bash
# Visit: https://cloud.walletconnect.com/
# Create a project and copy your Project ID
```

### 2. Setup Frontend Environment
```bash
cd frontend
cp .env.example .env.local
# Edit .env.local and add:
# NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_id_here
```

### 3. Deploy Smart Contract to Base Sepolia
```bash
# Setup root environment
cp .env.example .env
# Edit .env with your private key and RPC URL

# Install Foundry dependencies
forge install

# Run tests (should pass all 43)
forge test -vv

# Deploy contract
~/.foundry/bin/forge script script/Deploy.s.sol:DeploySimpleLottery \
  --rpc-url base_sepolia \
  --broadcast \
  --verify
```

### 4. Update Contract Address
After deployment, copy the contract address and update `frontend/lib/contracts.ts`:
```typescript
export const LOTTERY_ADDRESS: Record<number, Address> = {
  84532: '0x...', // Base Sepolia (from deployment)
  8453: '0x...', // Base mainnet (when ready)
};
```

## Development Commands

```bash
# Frontend
cd frontend
yarn dev          # Start dev server on :3000
yarn build        # Production build
yarn lint         # ESLint check

# Smart Contracts
forge build       # Compile
forge test        # Run tests
forge coverage    # Coverage report
```

## Deployment Checklist

- [ ] Deploy contract to Base Sepolia
- [ ] Get contract address from deployment
- [ ] Update contract address in `frontend/lib/contracts.ts`
- [ ] Get WalletConnect Project ID
- [ ] Create `.env.local` with Project ID
- [ ] Test frontend with real wallet
- [ ] Deploy frontend to Vercel/hosting
- [ ] Security review before mainnet

## Key Features Implemented
✅ Daily lottery rounds (24 hours)
✅ Ticket purchasing (0.01 ETH each, max 10 per tx)
✅ Real-time countdown timer
✅ Prize pool display
✅ Wallet integration
✅ Transaction status feedback
✅ Responsive design
✅ Web3 hooks for contract interaction

## Testing
- Smart contract: 43/43 tests passing
- Frontend: Compiles without errors
- Responsiveness: Mobile & desktop optimized
