'use client'
import React, { useState } from 'react';
import { Search, ChevronDown, Wallet, TrendingUp, Shield, Clock } from 'lucide-react';

export default function BorrowerDashboard() {
  const [selectedCollateral, setSelectedCollateral] = useState('ETH');
  const [orderType, setOrderType] = useState<'market' | 'limit'>('market');
  const [collateralAmount, setCollateralAmount] = useState('');
  const [borrowAmount, setBorrowAmount] = useState('');
  const [limitRate, setLimitRate] = useState('');
  const [selectedPool, setSelectedPool] = useState<string | null>(null);

  const availablePools = [
    {
      id: '1',
      asset: 'USDC',
      liquidity: '12.5M',
      rate: '4.25%',
      ltv: '75%',
      collateral: 'ETH',
      provider: 'Aave V3',
      utilization: '68%'
    },
    {
      id: '2',
      asset: 'DAI',
      liquidity: '8.3M',
      rate: '3.89%',
      ltv: '80%',
      collateral: 'ETH',
      provider: 'Compound',
      utilization: '72%'
    },
    {
      id: '3',
      asset: 'USDT',
      liquidity: '15.2M',
      rate: '4.50%',
      ltv: '70%',
      collateral: 'ETH',
      provider: 'MakerDAO',
      utilization: '65%'
    },
    {
      id: '4',
      asset: 'USDC',
      liquidity: '6.7M',
      rate: '3.95%',
      ltv: '75%',
      collateral: 'WBTC',
      provider: 'Morpho',
      utilization: '71%'
    },
    {
      id: '5',
      asset: 'DAI',
      liquidity: '9.8M',
      rate: '4.10%',
      ltv: '78%',
      collateral: 'ETH',
      provider: 'Spark',
      utilization: '69%'
    }
  ];

  const collateralOptions = ['ETH', 'WBTC', 'USDC', 'DAI', 'USDT'];

  const handleCreateOrder = () => {
    if (!selectedPool || !collateralAmount || !borrowAmount) {
      alert('Please fill in all required fields');
      return;
    }
    console.log('Creating order:', {
      pool: selectedPool,
      collateral: selectedCollateral,
      collateralAmount,
      borrowAmount,
      orderType,
      limitRate: orderType === 'limit' ? limitRate : null
    });
    alert('Order created successfully!');
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-slate-900">
      {/* Navigation */}
      <nav className="border-b border-white/10 bg-slate-900/50 backdrop-blur-xl">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="flex h-16 items-center justify-between">
            <div className="flex items-center gap-8">
              <div className="flex items-center gap-2">
                <div className="h-8 w-8 rounded-lg bg-gradient-to-br from-blue-400 to-blue-600" />
                <span className="text-xl font-bold text-white">CredBook</span>
              </div>
              <div className="hidden md:flex items-center gap-1">
                {['Dashboard', 'Earn', 'Borrow', 'Explore', 'Migrate'].map((item) => (
                  <button
                    key={item}
                    className={`rounded-lg px-4 py-2 text-sm font-medium transition-colors ${
                      item === 'Borrow'
                        ? 'bg-white/10 text-white'
                        : 'text-gray-300 hover:bg-white/5 hover:text-white'
                    }`}
                  >
                    {item}
                  </button>
                ))}
              </div>
            </div>
            <div className="flex items-center gap-3">
              <button className="flex items-center gap-2 rounded-full bg-white/5 px-3 py-2 text-sm text-white backdrop-blur-sm hover:bg-white/10">
                <div className="h-6 w-6 rounded-full bg-gradient-to-br from-blue-400 to-purple-500" />
                <ChevronDown className="h-4 w-4" />
              </button>
              <button className="flex items-center gap-2 rounded-full bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700">
                <Wallet className="h-4 w-4" />
                Connect Wallet
              </button>
            </div>
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        {/* Stats */}
        <div className="mb-8 grid grid-cols-1 gap-4 md:grid-cols-3">
          <div className="rounded-xl bg-white/5 p-6 backdrop-blur-sm border border-white/10">
            <div className="flex items-center gap-3 mb-2">
              <div className="rounded-lg bg-blue-500/20 p-2">
                <TrendingUp className="h-5 w-5 text-blue-400" />
              </div>
              <span className="text-sm text-gray-400">Total Borrowed</span>
            </div>
            <p className="text-3xl font-bold text-white">$0.00</p>
            <p className="text-sm text-gray-500 mt-1">Available: $0.00</p>
          </div>
          <div className="rounded-xl bg-white/5 p-6 backdrop-blur-sm border border-white/10">
            <div className="flex items-center gap-3 mb-2">
              <div className="rounded-lg bg-purple-500/20 p-2">
                <Shield className="h-5 w-5 text-purple-400" />
              </div>
              <span className="text-sm text-gray-400">Total Collateral</span>
            </div>
            <p className="text-3xl font-bold text-white">$0.00</p>
            <p className="text-sm text-gray-500 mt-1">Health Factor: ∞</p>
          </div>
          <div className="rounded-xl bg-white/5 p-6 backdrop-blur-sm border border-white/10">
            <div className="flex items-center gap-3 mb-2">
              <div className="rounded-lg bg-green-500/20 p-2">
                <Clock className="h-5 w-5 text-green-400" />
              </div>
              <span className="text-sm text-gray-400">Active Orders</span>
            </div>
            <p className="text-3xl font-bold text-white">0</p>
            <p className="text-sm text-gray-500 mt-1">No pending orders</p>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
          {/* Create Order Panel */}
          <div className="lg:col-span-1">
            <div className="rounded-xl bg-white/5 p-6 backdrop-blur-sm border border-white/10">
              <h2 className="mb-6 text-xl font-bold text-white">Create Borrow Order</h2>

              {/* Order Type */}
              <div className="mb-6">
                <label className="mb-2 block text-sm font-medium text-gray-300">Order Type</label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    onClick={() => setOrderType('market')}
                    className={`rounded-lg py-2 text-sm font-medium transition-colors ${
                      orderType === 'market'
                        ? 'bg-blue-600 text-white'
                        : 'bg-white/5 text-gray-400 hover:bg-white/10'
                    }`}
                  >
                    Market
                  </button>
                  <button
                    onClick={() => setOrderType('limit')}
                    className={`rounded-lg py-2 text-sm font-medium transition-colors ${
                      orderType === 'limit'
                        ? 'bg-blue-600 text-white'
                        : 'bg-white/5 text-gray-400 hover:bg-white/10'
                    }`}
                  >
                    Limit
                  </button>
                </div>
              </div>

              {/* Collateral Type */}
              <div className="mb-4">
                <label className="mb-2 block text-sm font-medium text-gray-300">Collateral Type</label>
                <div className="relative">
                  <select
                    value={selectedCollateral}
                    onChange={(e) => setSelectedCollateral(e.target.value)}
                    className="w-full appearance-none rounded-lg bg-white/5 border border-white/10 px-4 py-3 pr-10 text-white focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50"
                  >
                    {collateralOptions.map((option) => (
                      <option key={option} value={option} className="bg-slate-800">
                        {option}
                      </option>
                    ))}
                  </select>
                  <ChevronDown className="absolute right-3 top-1/2 h-5 w-5 -translate-y-1/2 text-gray-400 pointer-events-none" />
                </div>
              </div>

              {/* Collateral Amount */}
              <div className="mb-4">
                <label className="mb-2 block text-sm font-medium text-gray-300">Collateral Amount</label>
                <div className="relative">
                  <input
                    type="number"
                    value={collateralAmount}
                    onChange={(e) => setCollateralAmount(e.target.value)}
                    placeholder="0.00"
                    className="w-full rounded-lg bg-white/5 border border-white/10 px-4 py-3 text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50"
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-gray-400">
                    {selectedCollateral}
                  </span>
                </div>
                <p className="mt-1 text-xs text-gray-500">Balance: 0.00 {selectedCollateral}</p>
              </div>

              {/* Borrow Amount */}
              <div className="mb-4">
                <label className="mb-2 block text-sm font-medium text-gray-300">Borrow Amount</label>
                <input
                  type="number"
                  value={borrowAmount}
                  onChange={(e) => setBorrowAmount(e.target.value)}
                  placeholder="0.00"
                  className="w-full rounded-lg bg-white/5 border border-white/10 px-4 py-3 text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50"
                />
              </div>

              {/* Limit Rate (only for limit orders) */}
              {orderType === 'limit' && (
                <div className="mb-6">
                  <label className="mb-2 block text-sm font-medium text-gray-300">Target Rate (%)</label>
                  <input
                    type="number"
                    value={limitRate}
                    onChange={(e) => setLimitRate(e.target.value)}
                    placeholder="4.25"
                    step="0.01"
                    className="w-full rounded-lg bg-white/5 border border-white/10 px-4 py-3 text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50"
                  />
                </div>
              )}

              {/* Create Order Button */}
              <button
                onClick={handleCreateOrder}
                className="w-full rounded-lg bg-gradient-to-r from-blue-600 to-blue-700 py-3 font-medium text-white hover:from-blue-700 hover:to-blue-800 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                disabled={!selectedPool}
              >
                {selectedPool ? 'Create Order' : 'Select a Pool First'}
              </button>

              {selectedPool && (
                <p className="mt-3 text-center text-xs text-gray-400">
                  Selected: Pool #{selectedPool}
                </p>
              )}
            </div>
          </div>

          {/* Available Pools */}
          <div className="lg:col-span-2">
            <div className="rounded-xl bg-white/5 p-6 backdrop-blur-sm border border-white/10">
              <div className="mb-6 flex items-center justify-between">
                <h2 className="text-xl font-bold text-white">Available Liquidity Pools</h2>
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
                  <input
                    type="text"
                    placeholder="Search pools..."
                    className="rounded-lg bg-white/5 border border-white/10 py-2 pl-10 pr-4 text-sm text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50"
                  />
                </div>
              </div>

              <div className="space-y-3">
                {availablePools.map((pool) => (
                  <div
                    key={pool.id}
                    onClick={() => setSelectedPool(pool.id)}
                    className={`cursor-pointer rounded-lg border p-4 transition-all hover:scale-[1.02] ${
                      selectedPool === pool.id
                        ? 'border-blue-500 bg-blue-500/10'
                        : 'border-white/10 bg-white/5 hover:border-white/20'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-4">
                        <div className="flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-br from-blue-400 to-purple-500 text-lg font-bold text-white">
                          {pool.asset.slice(0, 1)}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <h3 className="font-semibold text-white">{pool.asset}</h3>
                            <span className="rounded-full bg-blue-500/20 px-2 py-0.5 text-xs text-blue-300">
                              {pool.provider}
                            </span>
                          </div>
                          <p className="text-sm text-gray-400">Collateral: {pool.collateral}</p>
                        </div>
                      </div>
                      <div className="text-right">
                        <p className="text-lg font-bold text-green-400">{pool.rate}</p>
                        <p className="text-xs text-gray-500">APY</p>
                      </div>
                    </div>
                    <div className="mt-4 grid grid-cols-3 gap-4 border-t border-white/10 pt-3">
                      <div>
                        <p className="text-xs text-gray-500">Liquidity</p>
                        <p className="text-sm font-medium text-white">${pool.liquidity}</p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Max LTV</p>
                        <p className="text-sm font-medium text-white">{pool.ltv}</p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Utilization</p>
                        <p className="text-sm font-medium text-white">{pool.utilization}</p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}