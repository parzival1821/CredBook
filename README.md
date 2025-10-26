📌CredBook

Overview:
This project introduces an on-chain orderbook-based lending platform where multiple isolated lending pools compete to provide the best available interest rates to borrowers — powered by efficient rate sorting and real-time price oracles.

🧱 Tech Stack
Layer	Technology
Smart Contracts	Solidity + Foundry
Backend Oracle Listener	Node.js (JavaScript)
Frontend	Next.js + TypeScript + Tailwind CSS
Matching Engine	Red-Black Tree data structure
Price Feed	Pyth Network (sub-second price updates)

🚀 Project Setup
✅ Smart Contracts
```
cd contracts
forge install
forge build
```

✅ Backend — Pyth Oracle Listener
```
cd backend/pyth
npm install
npm start
```

This service listens to Pyth price updates and pushes fresh price data on-chain for accurate LTV management.

✅ Frontend — Orderbook UI

```
cd frontend
npm install
npm run dev
```

➡️ Ensure .env.local contains correct deployed addresses (see contract section below)

✅ Backend and frontend each maintain their own package.json

🌍 Contract Deployment — Ethereum Sepolia ✅ Verified
🧩 Core System
Component	Address
Orderbook (main entrypoint)	0x8b747A7f7015a7B2e78c9B31D37f84FCA3a88f4F

📈 Interest Rate Models
IRM	Address
LinearIRM1	0x5c1409dE9584B5f20677E1112B9508c9975dc6Bb

LinearIRM2	0x0B89a6995adaA6f1996e0D48257094A02e0124c5

KinkIRM1	0xF825E3Af429cC4833A7AfC69312eE8Baf3767D08

KinkIRM2	0xb1317b649181ef1dC6c01F27f5e8E5C00D735E2f


💧 Lending Pools

Pool	Address

Pool 0	0x19c35eE719E44F8412008969F741063868492ea2

Pool 1	0xceaf52C12E2af9B702A845812023387245ae1895

Pool 2	0x6b4e732873153e62FccA6d1BcAc861F1e96BAa57

Pool 3	0x9Ad831EDbe601209fa7F42b51d6466C7297F334B
🪙 Assets Used
SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
SEPOLIA_WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;

