'use client'
import React, { useState } from 'react';
import { TrendingUp, TrendingDown, DollarSign, Percent, Activity, ArrowUpRight, ArrowDownRight, RefreshCw, Eye, Info } from 'lucide-react';

// Mock data - replace with actual contract calls
const mockPools = [
  { 
    id: 0, 
    name: 'Linear IRM 1', 
    type: 'Linear',
    apy: '2% → 15%',
    currentRate: 8.5,
    totalSupply: 100000,
    totalBorrow: 45000,
    utilization: 45,
    yourSupply: 25000,
    yourEarnings: 2125,
    rateRange: { min: 2, max: 15 }
  },
  { 
    id: 1, 
    name: 'Linear IRM 2', 
    type: 'Linear',
    apy: '5% → 30%',
    currentRate: 17.5,
    totalSupply: 100000,
    totalBorrow: 65000,
    utilization: 65,
    yourSupply: 0,
    yourEarnings: 0,
    rateRange: { min: 5, max: 30 }
  },
  { 
    id: 2, 
    name: 'Kink IRM 1', 
    type: 'Kink',
    apy: '1% → 80% @ 80%',
    currentRate: 6.2,
    totalSupply: 100000,
    totalBorrow: 35000,
    utilization: 35,
    yourSupply: 50000,
    yourEarnings: 3100,
    rateRange: { min: 1, max: 80, kink: 80 }
  },
  { 
    id: 3, 
    name: 'Kink IRM 2', 
    type: 'Kink',
    apy: '2% → 150% @ 90%',
    currentRate: 8.8,
    totalSupply: 100000,
    totalBorrow: 52000,
    utilization: 52,
    yourSupply: 0,
    yourEarnings: 0,
    rateRange: { min: 2, max: 150, kink: 90 }
  }
];

const mockOrderbook = [
  { rate: 6.2, amount: 1000, pool: 'Kink IRM 1', utilization: 35 },
  { rate: 7.1, amount: 1000, pool: 'Kink IRM 1', utilization: 40 },
  { rate: 8.0, amount: 1000, pool: 'Linear IRM 1', utilization: 42 },
  { rate: 8.5, amount: 1000, pool: 'Linear IRM 1', utilization: 45 },
  { rate: 8.8, amount: 1000, pool: 'Kink IRM 2', utilization: 52 },
  { rate: 9.2, amount: 1000, pool: 'Linear IRM 1', utilization: 48 },
  { rate: 10.5, amount: 1000, pool: 'Linear IRM 1', utilization: 52 },
  { rate: 11.8, amount: 1000, pool: 'Kink IRM 2', utilization: 58 },
  { rate: 13.2, amount: 1000, pool: 'Linear IRM 2', utilization: 62 },
  { rate: 14.5, amount: 1000, pool: 'Linear IRM 2', utilization: 65 },
];

export default function CredbookLenderDashboard() {
  const [selectedPool, setSelectedPool] = useState(null);
  const [supplyAmount, setSupplyAmount] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [activeTab, setActiveTab] = useState('overview');

  const totalSupplied = mockPools.reduce((sum, pool) => sum + pool.yourSupply, 0);
  const totalEarnings = mockPools.reduce((sum, pool) => sum + pool.yourEarnings, 0);
  const avgAPY = totalSupplied > 0 ? (totalEarnings / totalSupplied) * 100 : 0;

  const handleSupply = (poolId) => {
    console.log('Supply', supplyAmount, 'to pool', poolId);
    // Call: credbook.supplyLiquidity(poolId, amount)
  };

  const handleWithdraw = (poolId) => {
    console.log('Withdraw', withdrawAmount, 'from pool', poolId);
    // Call: credbook.withdrawLiquidity(poolId, amount)
  };

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
                <p className="text-xs text-slate-400">Lender Dashboard</p>
              </div>
            </div>
            <button className="flex items-center gap-2 px-4 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg transition-colors">
              <div className="w-2 h-2 bg-emerald-400 rounded-full animate-pulse" />
              <span className="text-sm">0x742d...35a3</span>
            </button>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-6 py-8">
        {/* Stats Overview */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6">
            <div className="flex items-center justify-between mb-2">
              <span className="text-slate-400 text-sm">Total Supplied</span>
              <DollarSign className="w-5 h-5 text-emerald-400" />
            </div>
            <div className="text-3xl font-bold mb-1">
              ${totalSupplied.toLocaleString()}
            </div>
            <div className="flex items-center gap-1 text-emerald-400 text-sm">
              <ArrowUpRight className="w-4 h-4" />
              <span>Active in {mockPools.filter(p => p.yourSupply > 0).length} pools</span>
            </div>
          </div>

          <div className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6">
            <div className="flex items-center justify-between mb-2">
              <span className="text-slate-400 text-sm">Total Earnings</span>
              <TrendingUp className="w-5 h-5 text-cyan-400" />
            </div>
            <div className="text-3xl font-bold mb-1">
              ${totalEarnings.toLocaleString()}
            </div>
            <div className="flex items-center gap-1 text-cyan-400 text-sm">
              <ArrowUpRight className="w-4 h-4" />
              <span>+{avgAPY.toFixed(2)}% APY</span>
            </div>
          </div>

          <div className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6">
            <div className="flex items-center justify-between mb-2">
              <span className="text-slate-400 text-sm">Market Avg Rate</span>
              <Percent className="w-5 h-5 text-violet-400" />
            </div>
            <div className="text-3xl font-bold mb-1">
              {(mockOrderbook[0].rate).toFixed(2)}%
            </div>
            <div className="flex items-center gap-1 text-slate-400 text-sm">
              <span>Best available rate</span>
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
        </div>

        {/* Orderbook View */}
        {activeTab === 'orderbook' && (
          <div className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-xl font-bold">Live Orderbook</h2>
              <button className="flex items-center gap-2 px-4 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg transition-colors text-sm">
                <RefreshCw className="w-4 h-4" />
                Refresh
              </button>
            </div>

            <div className="space-y-2">
              <div className="grid grid-cols-12 gap-4 text-xs text-slate-400 font-medium pb-2 border-b border-slate-800">
                <div className="col-span-2">Rate</div>
                <div className="col-span-2">Amount</div>
                <div className="col-span-3">Pool</div>
                <div className="col-span-2">Utilization</div>
                <div className="col-span-3">Depth Chart</div>
              </div>

              {mockOrderbook.map((order, idx) => (
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
                    ${order.amount.toLocaleString()}
                  </div>
                  <div className="col-span-3">
                    <span className="text-xs text-slate-400">{order.pool}</span>
                  </div>
                  <div className="col-span-2">
                    <div className="flex items-center gap-2">
                      <div className="flex-1 h-1.5 bg-slate-800 rounded-full overflow-hidden">
                        <div
                          className="h-full bg-gradient-to-r from-emerald-400 to-cyan-400"
                          style={{ width: `${order.utilization}%` }}
                        />
                      </div>
                      <span className="text-xs text-slate-400 w-10">
                        {order.utilization}%
                      </span>
                    </div>
                  </div>
                  <div className="col-span-3">
                    <div className="h-8 flex items-end gap-0.5">
                      {Array.from({ length: 10 }).map((_, i) => (
                        <div
                          key={i}
                          className="flex-1 bg-emerald-400/20 rounded-t"
                          style={{
                            height: `${Math.max(20, (idx + 1) * 8 - i * 5)}%`,
                            opacity: i <= idx ? 1 : 0.3
                          }}
                        />
                      ))}
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="mt-6 p-4 bg-slate-800/50 rounded-lg">
              <div className="flex items-start gap-3">
                <Info className="w-5 h-5 text-cyan-400 flex-shrink-0 mt-0.5" />
                <div className="text-sm text-slate-300">
                  <p className="font-medium mb-1">How the Orderbook Works</p>
                  <p className="text-slate-400">
                    Each pool quotes 5 orders at different rates based on utilization. 
                    Borrowers automatically match with the lowest rates. When orders fill, 
                    pools requote and the orderbook re-sorts in real-time.
                  </p>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Pools View */}
        {activeTab === 'pools' && (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {mockPools.map(pool => (
              <div
                key={pool.id}
                className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6 hover:border-slate-700 transition-colors"
              >
                <div className="flex items-start justify-between mb-4">
                  <div>
                    <h3 className="text-lg font-bold mb-1">{pool.name}</h3>
                    <span className="text-xs text-slate-400 px-2 py-1 bg-slate-800 rounded">
                      {pool.type}
                    </span>
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
                          style={{ width: `${pool.utilization}%` }}
                        />
                      </div>
                      <span className="text-sm font-medium">{pool.utilization}%</span>
                    </div>
                  </div>

                  <div className="flex justify-between items-center pt-2 border-t border-slate-800">
                    <span className="text-slate-400 text-sm">Your Supply</span>
                    <span className="text-lg font-bold">
                      ${pool.yourSupply.toLocaleString()}
                    </span>
                  </div>

                  {pool.yourSupply > 0 && (
                    <div className="flex justify-between items-center">
                      <span className="text-slate-400 text-sm">Your Earnings</span>
                      <span className="text-emerald-400 font-medium">
                        +${pool.yourEarnings.toLocaleString()}
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
                          className="px-6 py-2 bg-gradient-to-r from-emerald-400 to-cyan-400 hover:from-emerald-500 hover:to-cyan-500 text-slate-950 font-medium rounded-lg transition-all"
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
                            className="flex-1 bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-emerald-400"
                          />
                          <button
                            onClick={() => handleWithdraw(pool.id)}
                            className="px-6 py-2 bg-slate-700 hover:bg-slate-600 text-white font-medium rounded-lg transition-colors"
                          >
                            Withdraw
                          </button>
                        </div>
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
                <div className="space-y-3">
                  {mockPools.filter(p => p.yourSupply > 0).map(pool => (
                    <div key={pool.id} className="flex items-center justify-between py-2">
                      <div>
                        <div className="font-medium">{pool.name}</div>
                        <div className="text-sm text-slate-400">
                          {pool.utilization}% utilized
                        </div>
                      </div>
                      <div className="text-right">
                        <div className="font-bold">${pool.yourSupply.toLocaleString()}</div>
                        <div className="text-sm text-emerald-400">
                          {pool.currentRate.toFixed(2)}% APY
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6">
                <h3 className="text-lg font-bold mb-4">Market Activity</h3>
                <div className="space-y-4">
                  <div className="flex justify-between items-center">
                    <span className="text-slate-400">Total Market Size</span>
                    <span className="font-bold">$400,000</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-slate-400">Active Borrows</span>
                    <span className="font-bold">$197,000</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-slate-400">Avg Utilization</span>
                    <span className="font-bold">49.25%</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-slate-400">Active Pools</span>
                    <span className="font-bold">4</span>
                  </div>
                </div>
              </div>
            </div>

            {/* Rate Comparison Chart */}
            <div className="bg-slate-900/50 backdrop-blur-xl border border-slate-800 rounded-2xl p-6">
              <h3 className="text-lg font-bold mb-6">Pool Rate Comparison</h3>
              <div className="space-y-4">
                {mockPools.map(pool => (
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
          </div>
        )}
      </div>
    </div>
  );
}