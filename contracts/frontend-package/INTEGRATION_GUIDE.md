# 🏦 Credbook Frontend Integration Guide

## 📦 What You Need

### Contract Addresses (from `addresses.json`)
- **Orderbook**: Main contract for borrowing/repaying
- **Pool 0-3**: Individual lending pools for lenders
- **USDC**: Sepolia USDC token
- **WETH**: Sepolia Wrapped ETH token

### ABIs (in `abis/` folder)
- `Orderbook.json` - For borrowing/viewing orders
- `LendingPool.json` - For lending to pools
- `ERC20.json` - For token approvals

---

## 🚀 Quick Start

### Setup
```javascript
import { ethers } from 'ethers';
import OrderbookABI from './abis/Orderbook.json';
import LendingPoolABI from './abis/LendingPool.json';
import ERC20ABI from './abis/ERC20.json';
import addresses from './addresses.json';

const provider = new ethers.providers.Web3Provider(window.ethereum);
const signer = provider.getSigner();

// Initialize contracts
const orderbook = new ethers.Contract(addresses.orderbook, OrderbookABI, signer);
const usdc = new ethers.Contract(addresses.usdc, ERC20ABI, signer);
const weth = new ethers.Contract(addresses.weth, ERC20ABI, signer);

// Initialize pools
const pool0 = new ethers.Contract(addresses.pools.pool0, LendingPoolABI, signer);
const pool1 = new ethers.Contract(addresses.pools.pool1, LendingPoolABI, signer);
const pool2 = new ethers.Contract(addresses.pools.pool2, LendingPoolABI, signer);
const pool3 = new ethers.Contract(addresses.pools.pool3, LendingPoolABI, signer);
```

---

## 👛 For Lenders (Supplying Liquidity)

### Supply USDC to a Pool
```javascript
async function supplyLiquidity(poolIndex, amountUSDC) {
  const pools = [pool0, pool1, pool2, pool3];
  const pool = pools[poolIndex];
  
  // USDC has 6 decimals
  const amount = ethers.utils.parseUnits(amountUSDC.toString(), 6);
  
  // Step 1: Approve pool to spend USDC
  const approveTx = await usdc.approve(pool.address, amount);
  await approveTx.wait();
  console.log('✅ USDC approved');
  
  // Step 2: Supply to pool
  const userAddress = await signer.getAddress();
  const marketId = poolIndex + 1; // Pool 0 = market 1, etc.
  
  const supplyTx = await pool.supply(
    marketId,
    amount,
    0, // shares (0 = use assets)
    userAddress, // onBehalf (who receives shares)
    "0x" // empty data
  );
  await supplyTx.wait();
  console.log('✅ Liquidity supplied!');
  
  // Refresh orderbook
  await orderbook.refreshOrderbook();
}

// Example: Supply 1000 USDC to Pool 0
await supplyLiquidity(0, 1000);
```

### Withdraw Liquidity
```javascript
async function withdrawLiquidity(poolIndex, amountUSDC) {
  const pools = [pool0, pool1, pool2, pool3];
  const pool = pools[poolIndex];
  
  const amount = ethers.utils.parseUnits(amountUSDC.toString(), 6);
  const userAddress = await signer.getAddress();
  const marketId = poolIndex + 1;
  
  const withdrawTx = await pool.withdraw(
    marketId,
    amount,
    0, // shares
    userAddress, // onBehalf
    userAddress  // receiver
  );
  await withdrawTx.wait();
  console.log('✅ Liquidity withdrawn!');
}
```

---

## 💸 For Borrowers

### Borrow USDC (with WETH as collateral)
```javascript
async function borrow(borrowAmountUSDC, collateralAmountWETH) {
  const userAddress = await signer.getAddress();
  
  // Parse amounts (USDC = 6 decimals, WETH = 18 decimals)
  const borrowAmount = ethers.utils.parseUnits(borrowAmountUSDC.toString(), 6);
  const collateralAmount = ethers.utils.parseUnits(collateralAmountWETH.toString(), 18);
  
  // Step 1: Approve Orderbook to spend WETH
  const approveTx = await weth.approve(orderbook.address, collateralAmount);
  await approveTx.wait();
  console.log('✅ WETH approved');
  
  // Step 2: Borrow
  const maxRate = ethers.constants.MaxUint256; // Accept any rate
  
  const borrowTx = await orderbook.matchBorrowOrder(
    userAddress,
    borrowAmount,
    maxRate,
    collateralAmount
  );
  await borrowTx.wait();
  console.log('✅ Borrowed successfully!');
  console.log(`You received ${borrowAmountUSDC} USDC`);
}

// Example: Borrow 5000 USDC with 2 WETH collateral
await borrow(5000, 2);
```

### Check Your Debt (including interest!)
```javascript
async function checkDebt() {
  const userAddress = await signer.getAddress();
  
  // Get actual debt (includes accrued interest)
  const actualDebt = await orderbook.getActualDebt(userAddress);
  const debtUSDC = ethers.utils.formatUnits(actualDebt, 6);
  
  console.log(`Your debt: ${debtUSDC} USDC`);
  return actualDebt;
}
```

### Check Your Positions
```javascript
async function getPositions() {
  const userAddress = await signer.getAddress();
  
  const positions = await orderbook.getBorrowerPositions(userAddress);
  
  positions.forEach((pos, i) => {
    console.log(`Position ${i}:`);
    console.log(`  Pool: ${pos.pool}`);
    console.log(`  Amount: ${ethers.utils.formatUnits(pos.amount, 6)} USDC`);
    console.log(`  Timestamp: ${new Date(pos.timestamp * 1000).toLocaleString()}`);
  });
  
  return positions;
}
```

### Repay Loan
```javascript
async function repay(repayAmountUSDC) {
  const userAddress = await signer.getAddress();
  const repayAmount = ethers.utils.parseUnits(repayAmountUSDC.toString(), 6);
  
  // Step 1: Approve Orderbook to spend USDC
  const approveTx = await usdc.approve(orderbook.address, repayAmount);
  await approveTx.wait();
  console.log('✅ USDC approved for repayment');
  
  // Step 2: Repay
  const repayTx = await orderbook.fulfillRepay(userAddress, repayAmount);
  await repayTx.wait();
  console.log('✅ Loan repaid!');
}

// Example: Repay full debt including interest
const debt = await checkDebt();
await repay(ethers.utils.formatUnits(debt, 6));
```

---

## 📊 View Functions (Read-Only)

### Get All Orders (Orderbook)
```javascript
async function getOrderbook() {
  const orders = await orderbook.getAllOrders();
  
  console.log('📖 Orderbook:');
  orders.forEach((order, i) => {
    const rateAPY = (order.rate * 31536000 * 100) / 1e18; // Convert to APY %
    const utilization = (order.utilization * 100) / 1e18;
    
    console.log(`Order ${i}:`);
    console.log(`  Pool: ${order.pool}`);
    console.log(`  Amount: ${ethers.utils.formatUnits(order.amount, 6)} USDC`);
    console.log(`  Rate: ${rateAPY.toFixed(2)}% APY`);
    console.log(`  Utilization: ${utilization.toFixed(2)}%`);
  });
  
  return orders;
}
```

### Get Best Rate
```javascript
async function getBestRate() {
  const ratePerSecond = await orderbook.getBestRate();
  
  // Convert to APY percentage
  const APY = (ratePerSecond * 31536000 * 100) / 1e18;
  
  console.log(`Best rate: ${APY.toFixed(2)}% APY`);
  return APY;
}
```

### Refresh Orderbook
```javascript
async function refreshOrderbook() {
  const tx = await orderbook.refreshOrderbook();
  await tx.wait();
  console.log('✅ Orderbook refreshed');
}
```

### Check Pool Stats
```javascript
async function getPoolStats(poolIndex) {
  const pools = [pool0, pool1, pool2, pool3];
  const pool = pools[poolIndex];
  const marketId = poolIndex + 1;
  
  const market = await pool.market(marketId);
  
  const totalSupply = ethers.utils.formatUnits(market.totalSupplyAssets, 6);
  const totalBorrow = ethers.utils.formatUnits(market.totalBorrowAssets, 6);
  const utilization = market.totalSupplyAssets > 0 
    ? (market.totalBorrowAssets * 100) / market.totalSupplyAssets
    : 0;
  
  console.log(`Pool ${poolIndex} Stats:`);
  console.log(`  Total Supply: ${totalSupply} USDC`);
  console.log(`  Total Borrow: ${totalBorrow} USDC`);
  console.log(`  Utilization: ${utilization.toFixed(2)}%`);
}
```

---

## 🎯 Complete Example: Borrow Flow
```javascript
async function completeBorrowFlow() {
  const userAddress = await signer.getAddress();
  
  // 1. Check orderbook for best rate
  console.log('1️⃣ Checking orderbook...');
  const bestRate = await getBestRate();
  await getOrderbook();
  
  // 2. Check user balances
  console.log('\n2️⃣ Checking balances...');
  const wethBalance = await weth.balanceOf(userAddress);
  console.log(`WETH Balance: ${ethers.utils.formatEther(wethBalance)} WETH`);
  
  // 3. Borrow
  console.log('\n3️⃣ Borrowing...');
  await borrow(5000, 2); // Borrow 5000 USDC with 2 WETH
  
  // 4. Check positions
  console.log('\n4️⃣ Your positions:');
  await getPositions();
  
  // 5. Check debt
  console.log('\n5️⃣ Your debt:');
  await checkDebt();
  
  console.log('\n✅ Borrow flow complete!');
}
```

---

## ⚠️ Important Notes

### Decimals
- **USDC**: 6 decimals (1 USDC = 1000000)
- **WETH**: 18 decimals (1 WETH = 1000000000000000000)

### Approvals
- **For Borrowing**: Approve WETH to **Orderbook**
- **For Repaying**: Approve USDC to **Orderbook**
- **For Lending**: Approve USDC to **Pool** (not Orderbook!)

### Interest Rates
- Rates are in **per-second** format in WAD (1e18)
- To convert to APY: `(ratePerSecond * 31536000 * 100) / 1e18`
- Example: `317097919` per second = ~1% APY

### Pool IDs
```
Pool 0 = Market ID 1 (LinearIRM1: 2% → 15% APY)
Pool 1 = Market ID 2 (LinearIRM2: 5% → 30% APY)
Pool 2 = Market ID 3 (KinkIRM1: 1% → 80% APY, kink at 80%)
Pool 3 = Market ID 4 (KinkIRM2: 2% → 150% APY, kink at 90%)
```

### Gas Optimization
- Call `refreshOrderbook()` only when needed (after supply/withdraw)
- It's automatically called after borrow/repay

---

## 🐛 Common Issues

### "Insufficient allowance"
→ Make sure you approved the correct contract (Orderbook or Pool)

### "Unhealthy position"
→ You don't have enough collateral. Increase collateral or reduce borrow amount.

### "No orders within max rate"
→ Your `maxRate` is too low. Increase it or use `ethers.constants.MaxUint256`

### "Could not repay full amount"
→ You're trying to repay more than you borrowed. Check actual debt first.

---

## 📞 Need Help?

- Check Etherscan for transaction errors
- Use `console.log()` to debug
- Test on small amounts first!

---

## 🎉 You're Ready!

Start building your frontend with these examples. Good luck! 🚀