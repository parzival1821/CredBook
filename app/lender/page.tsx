'use client'
import React, { useState, useEffect } from 'react';
import { TrendingUp, TrendingDown, DollarSign, Percent, Activity, ArrowUpRight, ArrowDownRight, RefreshCw, Eye, Info, Wallet, ExternalLink } from 'lucide-react';
import { ethers } from 'ethers';

// Contract addresses on Sepolia
const ADDRESSES = {
  orderbook: '0x8b747A7f7015a7B2e78c9B31D37f84FCA3a88f4F',
  usdc: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238',
  weth: '0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14',
  pools: [
    '0x19c35eE719E44F8412008969F741063868492ea2',
    '0xceaf52C12E2af9B702A845812023387245ae1895',
    '0x6b4e732873153e62FccA6d1BcAc861F1e96BAa57',
    '0x9Ad831EDbe601209fa7F42b51d6466C7297F334B'
  ]
};

// ABIs (minimal - only functions we need)
const ORDERBOOK_ABI = [
  'function getAllOrders() external view returns (tuple(address pool, uint256 poolId, uint256 rate, uint256 availableAmount, uint256 utilization)[])',
  'function getBorrowerPositions(address borrower) external view returns (tuple(address pool, uint256 poolId, uint256 borrowedAmount, uint256 collateralAmount, uint256 rate)[])',
  'function getActualDebt(address borrower) external view returns (uint256)',
  'function getTotalBorrowed(address borrower) external view returns (uint256)',
  'function matchBorrowOrder(address borrower, uint256 borrowAmount, uint256 maxRate, uint256 collateralAmount) external',
  'function fulfillRepay(address borrower, uint256 repayAmount) external'
];

const POOL_ABI = [
  'function supply(uint256 id, uint256 assets, uint256 shares, address onBehalf, bytes data) external returns (uint256)',
  'function withdraw(uint256 id, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256)',
  'function market(uint256 id) external view returns (uint128 totalSupplyAssets, uint128 totalSupplyShares, uint128 totalBorrowAssets, uint128 totalBorrowShares, uint128 lastUpdate, uint128 fee)',
  'function supplyShares(uint256 id, address user) external view returns (uint256)',
  'function borrowShares(uint256 id, address user) external view returns (uint256)'
];

const ERC20_ABI = [
  'function approve(address spender, uint256 amount) external returns (bool)',
  'function allowance(address owner, address spender) external view returns (uint256)',
  'function balanceOf(address account) external view returns (uint256)',
  'function decimals() external view returns (uint8)'
];

export default function CredbookLenderDashboard() {
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [userAddress, setUserAddress] = useState('');
  const [isConnecting, setIsConnecting] = useState(false);
  
  const [pools, setPools] = useState([]);
  const [orderbook, setOrderbook] = useState([]);
  const [userPositions, setUserPositions] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  
  const [selectedPool, setSelectedPool] = useState(null);
  const [supplyAmount, setSupplyAmount] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [activeTab, setActiveTab] = useState('overview');
  
  const [usdcBalance, setUsdcBalance] = useState('0');
  const [txStatus, setTxStatus] = useState('');

  // Connect wallet
  const connectWallet = async () => {
    if (typeof window.ethereum === 'undefined') {
      alert('Please install MetaMask to use this app');
      return;
    }

    setIsConnecting(true);
    try {
      const web3Provider = new ethers.BrowserProvider(window.ethereum);
      const accounts = await web3Provider.send('eth_requestAccounts', []);
      const web3Signer = await web3Provider.getSigner();
      
      // Check network
      const network = await web3Provider.getNetwork();
      if (network.chainId !== 11155111n) { // Sepolia chainId
        alert('Please switch to Sepolia testnet');
        setIsConnecting(false);
        return;
      }

      setProvider(web3Provider);
      setSigner(web3Signer);
      setUserAddress(accounts[0]);
      
      // Load initial data
      await loadUserData(web3Provider, web3Signer, accounts[0]);
    } catch (error) {
      console.error('Failed to connect:', error);
      alert('Failed to connect wallet');
    } finally {
      setIsConnecting(false);
    }
  };

  // Load user data
  const loadUserData = async (web3Provider, web3Signer, address) => {
    setIsLoading(true);
    try {
      // Get USDC balance
      const usdcContract = new ethers.Contract(ADDRESSES.usdc, ERC20_ABI, web3Provider);
      const balance = await usdcContract.balanceOf(address);
      setUsdcBalance(ethers.formatUnits(balance, 6));

      // Load pool data
      await loadPools(web3Provider, address);
      
      // Load orderbook
      await loadOrderbook(web3Provider);
      
      // Load user positions
      await loadUserPositions(web3Provider, address);
    } catch (error) {
      console.error('Failed to load data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  // Load pools data
  const loadPools = async (web3Provider, address) => {
    const poolsData = [];
    
    for (let i = 0; i < ADDRESSES.pools.length; i++) {
      try {
        const poolContract = new ethers.Contract(ADDRESSES.pools[i], POOL_ABI, web3Provider);
        
        // Get market data for poolId = 1
        const market = await poolContract.market(1);
        const totalSupply = ethers.formatUnits(market.totalSupplyAssets, 6);
        const totalBorrow = ethers.formatUnits(market.totalBorrowAssets, 6);
        const utilization = market.totalSupplyAssets > 0 
          ? Number(market.totalBorrowAssets * 10000n / market.totalSupplyAssets) / 100
          : 0;
        
        // Get user supply shares
        const userShares = await poolContract.supplyShares(1, address);
        const yourSupply = market.totalSupplyShares > 0
          ? ethers.formatUnits(userShares * market.totalSupplyAssets / market.totalSupplyShares, 6)
          : '0';
        
        // Calculate current rate (simplified - would need IRM contract for exact rate)
        const baseRate = i < 2 ? 2 + (utilization * 0.13) : 1 + (utilization * 0.5);
        
        poolsData.push({
          id: i,
          address: ADDRESSES.pools[i],
          name: i < 2 ? `Linear IRM ${i + 1}` : `Kink IRM ${i - 1}`,
          type: i < 2 ? 'Linear' : 'Kink',
          apy: i < 2 ? (i === 0 ? '2% → 15%' : '5% → 30%') : (i === 2 ? '1% → 80% @ 80%' : '2% → 150% @ 90%'),
          currentRate: baseRate,
          totalSupply: parseFloat(totalSupply),
          totalBorrow: parseFloat(totalBorrow),
          utilization: utilization,
          yourSupply: parseFloat(yourSupply),
          yourEarnings: parseFloat(yourSupply) * baseRate / 100 // Simplified
        });
      } catch (error) {
        console.error(`Failed to load pool ${i}:`, error);
      }
    }
    
    setPools(poolsData);
  };

  // Load orderbook
  const loadOrderbook = async (web3Provider) => {
    try {
      const orderbookContract = new ethers.Contract(ADDRESSES.orderbook, ORDERBOOK_ABI, web3Provider);
      const orders = await orderbookContract.getAllOrders();
      
      const formattedOrders = orders.map(order => ({
        pool: order.pool,
        poolId: order.poolId.toString(),
        rate: Number(order.rate) / 100, // Assuming rate is in basis points * 100
        amount: parseFloat(ethers.formatUnits(order.availableAmount, 6)),
        utilization: Number(order.utilization) / 100
      }));
      
      setOrderbook(formattedOrders);
    } catch (error) {
      console.error('Failed to load orderbook:', error);
    }
  };

  // Load user positions
  const loadUserPositions = async (web3Provider, address) => {
    try {
      const orderbookContract = new ethers.Contract(ADDRESSES.orderbook, ORDERBOOK_ABI, web3Provider);
      const positions = await orderbookContract.getBorrowerPositions(address);
      
      setUserPositions(positions);
    } catch (error) {
      console.error('Failed to load positions:', error);
    }
  };

  // Supply to pool
  const handleSupply = async (poolId) => {
    if (!signer || !supplyAmount) return;
    
    setTxStatus('Approving USDC...');
    try {
      const amount = ethers.parseUnits(supplyAmount, 6);
      const poolAddress = ADDRESSES.pools[poolId];
      
      // Approve USDC
      const usdcContract = new ethers.Contract(ADDRESSES.usdc, ERC20_ABI, signer);
      const approveTx = await usdcContract.approve(poolAddress, amount);
      await approveTx.wait();
      
      setTxStatus('Supplying to pool...');
      
      // Supply to pool
      const poolContract = new ethers.Contract(poolAddress, POOL_ABI, signer);
      const supplyTx = await poolContract.supply(1, amount, 0, userAddress, '0x');
      await supplyTx.wait();
      
      setTxStatus('✅ Supply successful!');
      setSupplyAmount('');
      
      // Reload data
      await loadUserData(provider, signer, userAddress);
      
      setTimeout(() => setTxStatus(''), 3000);
    } catch (error) {
      console.error('Supply failed:', error);
      setTxStatus('❌ Transaction failed');
      setTimeout(() => setTxStatus(''), 3000);
    }
  };

  // Withdraw from pool
  const handleWithdraw = async (poolId) => {
    if (!signer || !withdrawAmount) return;
    
    setTxStatus('Withdrawing from pool...');
    try {
      const amount = ethers.parseUnits(withdrawAmount, 6);
      const poolAddress = ADDRESSES.pools[poolId];
      
      const poolContract = new ethers.Contract(poolAddress, POOL_ABI, signer);
      const withdrawTx = await poolContract.withdraw(1, amount, 0, userAddress, userAddress);
      await withdrawTx.wait();
      
      setTxStatus('✅ Withdrawal successful!');
      setWithdrawAmount('');
      
      // Reload data
      await loadUserData(provider, signer, userAddress);
      
      setTimeout(() => setTxStatus(''), 3000);
    } catch (error) {
      console.error('Withdraw failed:', error);
      setTxStatus('❌ Transaction failed');
      setTimeout(() => setTxStatus(''), 3000);
    }
  };

  // Refresh data
  const handleRefresh = async () => {
    if (!provider || !signer || !userAddress) return;
    await loadUserData(provider, signer, userAddress);
  };

  const totalSupplied = pools.reduce((sum, pool) => sum + pool.yourSupply, 0);
  const totalEarnings = pools.reduce((sum, pool) => sum + pool.yourEarnings, 0);
  const avgAPY = totalSupplied > 0 ? (totalEarnings / totalSupplied) * 100 : 0;
  const bestRate = orderbook.length > 0 ? orderbook[0].rate : 0;

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950 text-white">
      {/* Header */}
      <header className="border-b border-slate-800 backdrop-blur-xl bg-slate-950/50">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-gradient-to-br from-emerald-400 to-cyan-400 rounded-lg flex items-center justify-center">
                <Activity className="w-6 h-6 text-slate-950" />
              </div>
              <div>
                <h1 className="text-2xl font-bold bg-gradient-to-r from-emerald-400 to-cyan-400 bg-clip-text text-transparent">
                  Credbook
                </h1>
                <p className="text-xs text-slate-400">Lender Dashboard • Sepolia</p>
              </div>
            </div>
            
            {!userAddress ? (
              <button
                onClick={connectWallet}
                disabled={isConnecting}
                className="flex items-center gap-2 px-6 py-2 bg-gradient-to-r from-emerald-400 to-cyan-400 hover:from-emerald-500 hover:to-cyan-500 text-slate-950 font-medium rounded-lg transition-all disabled:opacity-50"
              >
                <Wallet className="w-4 h-4" />
                {isConnecting ? 'Connecting...' : 'Connect Wallet'}
              </button>
            ) : (
              <div className="flex items-center gap-3">
                <div className="text-right">
                  <div className="text-xs text-slate-400">USDC Balance</div>
                  <div className="text-sm font-medium">{parseFloat(usdcBalance).toFixed(2)}</div>
                </div>
                <button className="flex items-center gap-2 px-4 py-2 bg-slate-800 rounded-lg">
                  <div className="w-2 h-2 bg-emerald-400 rounded-full animate-pulse" />
                  <span className="text-sm">{userAddress.slice(0, 6)}...{userAddress.slice(-4)}</span>
                </button>
              </div>
            )}
          </div>
        </div>
      </header>

      {!userAddress ? (
        <div className="max-w-7xl mx-auto px-6 py-20 text-center">
          <div className="max-w-md mx-auto">
            <Wallet className="w-16 h-16 text-emerald-400 mx-auto mb-4" />
            <h2 className="text-2xl font-bold mb-2">Connect Your Wallet</h2>
            <p className="text-slate-400 mb-6">
              Connect your wallet to start supplying liquidity and earning yield
            </p>
            <button
              onClick={connectWallet}
              className="px-8 py-3 bg-gradient-to-r from-emerald-400 to-cyan-400 hover:from-emerald-500 hover:to-cyan-500 text-slate-950 font-medium rounded-lg transition-all"
            >
              Connect Wallet
            </button>
            <p className="text-xs text-slate-500 mt-4">
              Make sure you're on Sepolia testnet
            </p>
          </div>
        </div>
      ) : (
        <div className="max-w-7xl mx-auto px-6 py-8">
          {/* Transaction Status */}
          {txStatus && (
            <div className="mb-4 p-4 bg-slate-800 border border-slate-700 rounded-lg text-center">
              {txStatus}
            </div>
          )}

          {/* Stats Overview */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6">
              <div className="flex items-center justify-between mb-2">
                <span className="text-slate-400 text-sm">Total Supplied</span>
                <DollarSign className="w-5 h-5 text-emerald-400" />
              </div>
              <div className="text-3xl font-bold mb-1">
                ${totalSupplied.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div className="flex items-center gap-1 text-emerald-400 text-sm">
                <ArrowUpRight className="w-4 h-4" />
                <span>Active in {pools.filter(p => p.yourSupply > 0).length} pools</span>
              </div>
            </div>

            <div className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6">
              <div className="flex items-center justify-between mb-2">
                <span className="text-slate-400 text-sm">Est. Earnings</span>
                <TrendingUp className="w-5 h-5 text-cyan-400" />
              </div>
              <div className="text-3xl font-bold mb-1">
                ${totalEarnings.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div className="flex items-center gap-1 text-cyan-400 text-sm">
                <ArrowUpRight className="w-4 h-4" />
                <span>+{avgAPY.toFixed(2)}% APY</span>
              </div>
            </div>

            <div className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6">
              <div className="flex items-center justify-between mb-2">
                <span className="text-slate-400 text-sm">Best Market Rate</span>
                <Percent className="w-5 h-5 text-violet-400" />
              </div>
              <div className="text-3xl font-bold mb-1">
                {bestRate.toFixed(2)}%
              </div>
              <div className="flex items-center gap-1 text-slate-400 text-sm">
                <span>{orderbook.length} orders available</span>
              </div>
            </div>
          </div>

          {/* Navigation Tabs */}
          <div className="flex gap-2 mb-6 border-b border-slate-800">
            {['overview', 'orderbook', 'pools'].map(tab => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`px-6 py-3 text-sm font-medium transition-colors relative ${
                  activeTab === tab
                    ? 'text-emerald-400'
                    : 'text-slate-400 hover:text-slate-300'
                }`}
              >
                {tab.charAt(0).toUpperCase() + tab.slice(1)}
                {activeTab === tab && (
                  <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-gradient-to-r from-emerald-400 to-cyan-400" />
                )}
              </button>
            ))}
            <button
              onClick={handleRefresh}
              disabled={isLoading}
              className="ml-auto flex items-center gap-2 px-4 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg transition-colors text-sm disabled:opacity-50"
            >
              <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
              Refresh
            </button>
          </div>

          {/* Orderbook View */}
          {activeTab === 'orderbook' && (
            <div className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-bold">Live Orderbook</h2>
                <a
                  href={`https://sepolia.etherscan.io/address/${ADDRESSES.orderbook}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-1 text-sm text-slate-400 hover:text-emerald-400 transition-colors"
                >
                  View Contract <ExternalLink className="w-3 h-3" />
                </a>
              </div>

              {orderbook.length === 0 ? (
                <div className="text-center py-12 text-slate-400">
                  <Activity className="w-12 h-12 mx-auto mb-3 opacity-50" />
                  <p>No orders available</p>
                </div>
              ) : (
                <div className="space-y-2">
                  <div className="grid grid-cols-12 gap-4 text-xs text-slate-400 font-medium pb-2 border-b border-slate-800">
                    <div className="col-span-2">Rate</div>
                    <div className="col-span-2">Amount</div>
                    <div className="col-span-4">Pool</div>
                    <div className="col-span-4">Utilization</div>
                  </div>

                  {orderbook.slice(0, 20).map((order, idx) => (
                    <div
                      key={idx}
                      className="grid grid-cols-12 gap-4 items-center py-3 hover:bg-slate-800/50 rounded-lg px-2 transition-colors"
                    >
                      <div className="col-span-2">
                        <span className="text-emerald-400 font-mono font-bold">
                          {order.rate.toFixed(2)}%
                        </span>
                      </div>
                      <div className="col-span-2 text-slate-300">
                        ${order.amount.toFixed(0)}
                      </div>
                      <div className="col-span-4">
                        <div className="text-xs text-slate-400 truncate" title={order.pool}>
                          {order.pool.slice(0, 8)}...{order.pool.slice(-6)}
                        </div>
                      </div>
                      <div className="col-span-4">
                        <div className="flex items-center gap-2">
                          <div className="flex-1 h-1.5 bg-slate-800 rounded-full overflow-hidden">
                            <div
                              className="h-full bg-gradient-to-r from-emerald-400 to-cyan-400"
                              style={{ width: `${Math.min(100, order.utilization)}%` }}
                            />
                          </div>
                          <span className="text-xs text-slate-400 w-12">
                            {order.utilization.toFixed(1)}%
                          </span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              <div className="mt-6 p-4 bg-slate-800/50 rounded-lg">
                <div className="flex items-start gap-3">
                  <Info className="w-5 h-5 text-cyan-400 flex-shrink-0 mt-0.5" />
                  <div className="text-sm text-slate-300">
                    <p className="font-medium mb-1">How the Orderbook Works</p>
                    <p className="text-slate-400">
                      Each pool quotes orders at different rates based on utilization. 
                      Borrowers automatically match with the lowest rates. Supply to pools to provide liquidity.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Pools View */}
          {activeTab === 'pools' && (
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {pools.map(pool => (
                <div
                  key={pool.id}
                  className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6 hover:border-slate-700 transition-colors"
                >
                  <div className="flex items-start justify-between mb-4">
                    <div>
                      <h3 className="text-lg font-bold mb-1">{pool.name}</h3>
                      <div className="flex items-center gap-2">
                        <span className="text-xs text-slate-400 px-2 py-1 bg-slate-800 rounded">
                          {pool.type}
                        </span>
                        <a
                          href={`https://sepolia.etherscan.io/address/${pool.address}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-xs text-slate-500 hover:text-emerald-400"
                        >
                          <ExternalLink className="w-3 h-3" />
                        </a>
                      </div>
                    </div>
                    <button
                      onClick={() => setSelectedPool(pool.id === selectedPool ? null : pool.id)}
                      className="text-emerald-400 hover:text-emerald-300 transition-colors"
                    >
                      <Eye className="w-5 h-5" />
                    </button>
                  </div>

                  <div className="space-y-4 mb-4">
                    <div className="flex justify-between items-center">
                      <span className="text-slate-400 text-sm">Current Rate</span>
                      <span className="text-xl font-bold text-emerald-400">
                        {pool.currentRate.toFixed(2)}%
                      </span>
                    </div>

                    <div className="flex justify-between items-center">
                      <span className="text-slate-400 text-sm">APY Range</span>
                      <span className="text-sm font-mono text-slate-300">{pool.apy}</span>
                    </div>

                    <div className="flex justify-between items-center">
                      <span className="text-slate-400 text-sm">Utilization</span>
                      <div className="flex items-center gap-2">
                        <div className="w-24 h-2 bg-slate-800 rounded-full overflow-hidden">
                          <div
                            className="h-full bg-gradient-to-r from-emerald-400 to-cyan-400"
                            style={{ width: `${Math.min(100, pool.utilization)}%` }}
                          />
                        </div>
                        <span className="text-sm font-medium">{pool.utilization.toFixed(1)}%</span>
                      </div>
                    </div>

                    <div className="flex justify-between items-center pt-2 border-t border-slate-800">
                      <span className="text-slate-400 text-sm">Your Supply</span>
                      <span className="text-lg font-bold">
                        ${pool.yourSupply.toFixed(2)}
                      </span>
                    </div>

                    {pool.yourSupply > 0 && (
                      <div className="flex justify-between items-center">
                        <span className="text-slate-400 text-sm">Est. Earnings</span>
                        <span className="text-emerald-400 font-medium">
                          +${pool.yourEarnings.toFixed(2)}
                        </span>
                      </div>
                    )}
                  </div>

                  {selectedPool === pool.id && (
                    <div className="space-y-4 pt-4 border-t border-slate-800">
                      <div>
                        <label className="text-sm text-slate-400 mb-2 block">
                          Supply Amount (USDC)
                        </label>
                        <div className="flex gap-2">
                          <input
                            type="number"
                            value={supplyAmount}
                            onChange={(e) => setSupplyAmount(e.target.value)}
                            placeholder="0.00"
                            className="flex-1 bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-emerald-400"
                          />
                          <button
                            onClick={() => handleSupply(pool.id)}
                            disabled={!supplyAmount || parseFloat(supplyAmount) <= 0}
                            className="px-6 py-2 bg-gradient-to-r from-emerald-400 to-cyan-400 hover:from-emerald-500 hover:to-cyan-500 text-slate-950 font-medium rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                          >
                            Supply
                          </button>
                        </div>
                      </div>

                      {pool.yourSupply > 0 && (
                        <div>
                          <label className="text-sm text-slate-400 mb-2 block">
                            Withdraw Amount (USDC)
                          </label>
                          <div className="flex gap-2">
                            <input
                              type="number"
                              value={withdrawAmount}
                              onChange={(e) => setWithdrawAmount(e.target.value)}
                              placeholder="0.00"
                              max={pool.yourSupply}
                              className="flex-1 bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-emerald-400"
                            />
                            <button
                              onClick={() => handleWithdraw(pool.id)}
                              disabled={!withdrawAmount || parseFloat(withdrawAmount) <= 0}
                              className="px-6 py-2 bg-slate-700 hover:bg-slate-600 text-white font-medium rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                            >
                              Withdraw
                            </button>
                          </div>
                          <button
                            onClick={() => setWithdrawAmount(pool.yourSupply.toString())}
                            className="text-xs text-emerald-400 hover:text-emerald-300 mt-1"
                          >
                            Max: ${pool.yourSupply.toFixed(2)}
                          </button>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}

          {/* Overview Tab */}
          {activeTab === 'overview' && (
            <div className="space-y-6">
              {/* Quick Stats Grid */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6">
                  <h3 className="text-lg font-bold mb-4">Your Positions</h3>
                  {pools.filter(p => p.yourSupply > 0).length === 0 ? (
                    <div className="text-center py-8 text-slate-400">
                      <DollarSign className="w-12 h-12 mx-auto mb-3 opacity-50" />
                      <p className="text-sm">No active positions</p>
                      <p className="text-xs mt-1">Supply to a pool to start earning</p>
                    </div>
                  ) : (
                    <div className="space-y-3">
                      {pools.filter(p => p.yourSupply > 0).map(pool => (
                        <div key={pool.id} className="flex items-center justify-between py-2 border-b border-slate-800 last:border-0">
                          <div>
                            <div className="font-medium">{pool.name}</div>
                            <div className="text-sm text-slate-400">
                              {pool.utilization.toFixed(1)}% utilized
                            </div>
                          </div>
                          <div className="text-right">
                            <div className="font-bold">${pool.yourSupply.toFixed(2)}</div>
                            <div className="text-sm text-emerald-400">
                              {pool.currentRate.toFixed(2)}% APY
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                <div className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6">
                  <h3 className="text-lg font-bold mb-4">Market Activity</h3>
                  <div className="space-y-4">
                    <div className="flex justify-between items-center">
                      <span className="text-slate-400">Total Market Size</span>
                      <span className="font-bold">
                        ${pools.reduce((sum, p) => sum + p.totalSupply, 0).toFixed(0)}
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-slate-400">Active Borrows</span>
                      <span className="font-bold">
                        ${pools.reduce((sum, p) => sum + p.totalBorrow, 0).toFixed(0)}
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-slate-400">Avg Utilization</span>
                      <span className="font-bold">
                        {(pools.reduce((sum, p) => sum + p.utilization, 0) / pools.length).toFixed(2)}%
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-slate-400">Active Pools</span>
                      <span className="font-bold">{pools.length}</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Rate Comparison Chart */}
              <div className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6">
                <h3 className="text-lg font-bold mb-6">Pool Rate Comparison</h3>
                <div className="space-y-4">
                  {pools.map(pool => (
                    <div key={pool.id}>
                      <div className="flex justify-between items-center mb-2">
                        <span className="text-sm text-slate-300">{pool.name}</span>
                        <span className="text-sm font-mono text-emerald-400">
                          {pool.currentRate.toFixed(2)}%
                        </span>
                      </div>
                      <div className="h-2 bg-slate-800 rounded-full overflow-hidden">
                        <div
                          className="h-full bg-gradient-to-r from-emerald-400 to-cyan-400"
                          style={{ width: `${(pool.currentRate / 30) * 100}%` }}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Contract Addresses */}
              
            </div>
          )}
        </div>
      )}
    </div>
  );
}