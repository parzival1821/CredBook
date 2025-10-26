'use client'
import React, { useState } from 'react';
import { TrendingUp, TrendingDown, DollarSign, Percent, Users, Activity, Plus, Minus, RefreshCw, ChevronDown, ChevronUp } from 'lucide-react';

const CredbookLenderDashboard = () => {
  const [selectedPool, setSelectedPool] = useState(null);
  const [supplyAmount, setSupplyAmount] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [showSupplyModal, setShowSupplyModal] = useState(false);
  const [showWithdrawModal, setShowWithdrawModal] = useState(false);
  const [expandedOrder, setExpandedOrder] = useState(null);

  // Mock data based on the contract
  const totalStats = {
    totalDeposits: '$12,456,591.815',
    yourSupply: '$125,000.00',
    totalEarned: '$3,247.82',
    avgAPY: '8.45%'
  };

  const pools = [
    { 
      id: 0, 
      name: 'Pool Alpha', 
      totalSupply: '$100,000', 
      utilization: 45.2, 
      apy: 7.8,
      yourSupply: '$25,000',
      earned: '$1,247.32',
      borrowers: 8
    },
    { 
      id: 1, 
      name: 'Pool Beta', 
      totalSupply: '$100,000', 
      utilization: 62.8, 
      apy: 9.2,
      yourSupply: '$35,000',
      earned: '$1,523.18',
      borrowers: 12
    },
    { 
      id: 2, 
      name: 'Pool Gamma', 
      totalSupply: '$100,000', 
      utilization: 38.5, 
      apy: 6.9,
      yourSupply: '$40,000',
      earned: '$892.47',
      borrowers: 5
    },
    { 
      id: 3, 
      name: 'Pool Delta', 
      totalSupply: '$100,000', 
      utilization: 71.3, 
      apy: 10.5,
      yourSupply: '$25,000',
      earned: '$584.85',
      borrowers: 15
    }
  ];

  const orderbookOrders = [
    { id: 1, pool: 'Pool Delta', rate: 6.2, amount: '$1,000', utilization: 71.3, poolId: 3 },
    { id: 2, pool: 'Pool Beta', rate: 6.5, amount: '$1,000', utilization: 62.8, poolId: 1 },
    { id: 3, pool: 'Pool Delta', rate: 6.8, amount: '$1,000', utilization: 73.4, poolId: 3 },
    { id: 4, pool: 'Pool Alpha', rate: 7.1, amount: '$1,000', utilization: 45.2, poolId: 0 },
    { id: 5, pool: 'Pool Beta', rate: 7.3, amount: '$1,000', utilization: 65.1, poolId: 1 },
    { id: 6, pool: 'Pool Gamma', rate: 7.6, amount: '$1,000', utilization: 38.5, poolId: 2 },
    { id: 7, pool: 'Pool Alpha', rate: 7.8, amount: '$1,000', utilization: 47.8, poolId: 0 },
    { id: 8, pool: 'Pool Delta', rate: 8.1, amount: '$1,000', utilization: 76.2, poolId: 3 },
  ];

  const StatCard = ({ title, value, change, icon: Icon, trend }) => (
    <div className="bg-gradient-to-br from-slate-800 to-slate-900 rounded-xl p-6 border border-slate-700 hover:border-blue-500/50 transition-all">
      <div className="flex items-start justify-between mb-4">
        <div className="p-2 bg-blue-500/10 rounded-lg">
          <Icon className="w-5 h-5 text-blue-400" />
        </div>
        {change && (
          <div className={`flex items-center gap-1 text-sm ${trend === 'up' ? 'text-green-400' : 'text-red-400'}`}>
            {trend === 'up' ? <TrendingUp className="w-4 h-4" /> : <TrendingDown className="w-4 h-4" />}
            {change}
          </div>
        )}
      </div>
      <p className="text-slate-400 text-sm mb-1">{title}</p>
      <p className="text-2xl font-bold text-white">{value}</p>
    </div>
  );

  const PoolCard = ({ pool }) => (
    <div 
      className="bg-gradient-to-br from-slate-800 to-slate-900 rounded-xl p-6 border border-slate-700 hover:border-blue-500/50 transition-all cursor-pointer"
      onClick={() => setSelectedPool(pool)}
    >
      <div className="flex items-start justify-between mb-4">
        <div>
          <h3 className="text-lg font-bold text-white mb-1">{pool.name}</h3>
          <p className="text-slate-400 text-sm">Pool ID: {pool.id}</p>
        </div>
        <div className="text-right">
          <p className="text-2xl font-bold text-green-400">{pool.apy}%</p>
          <p className="text-slate-400 text-sm">APY</p>
        </div>
      </div>
      
      <div className="space-y-3 mb-4">
        <div>
          <div className="flex justify-between text-sm mb-1">
            <span className="text-slate-400">Utilization</span>
            <span className="text-white font-medium">{pool.utilization}%</span>
          </div>
          <div className="w-full bg-slate-700 rounded-full h-2">
            <div 
              className="bg-gradient-to-r from-blue-500 to-cyan-400 h-2 rounded-full transition-all"
              style={{ width: `${pool.utilization}%` }}
            />
          </div>
        </div>
        
        <div className="grid grid-cols-2 gap-3 pt-3 border-t border-slate-700">
          <div>
            <p className="text-slate-400 text-xs mb-1">Your Supply</p>
            <p className="text-white font-semibold">{pool.yourSupply}</p>
          </div>
          <div>
            <p className="text-slate-400 text-xs mb-1">Earned</p>
            <p className="text-green-400 font-semibold">{pool.earned}</p>
          </div>
        </div>
      </div>
      
      <div className="flex gap-2">
        <button 
          onClick={(e) => { e.stopPropagation(); setSelectedPool(pool); setShowSupplyModal(true); }}
          className="flex-1 bg-blue-500 hover:bg-blue-600 text-white py-2 rounded-lg font-medium transition-all flex items-center justify-center gap-2"
        >
          <Plus className="w-4 h-4" />
          Supply
        </button>
        <button 
          onClick={(e) => { e.stopPropagation(); setSelectedPool(pool); setShowWithdrawModal(true); }}
          className="flex-1 bg-slate-700 hover:bg-slate-600 text-white py-2 rounded-lg font-medium transition-all flex items-center justify-center gap-2"
        >
          <Minus className="w-4 h-4" />
          Withdraw
        </button>
      </div>
    </div>
  );

  const Modal = ({ show, onClose, title, children }) => {
    if (!show) return null;
    
    return (
      <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50" onClick={onClose}>
        <div className="bg-slate-800 rounded-xl p-6 max-w-md w-full mx-4 border border-slate-700" onClick={e => e.stopPropagation()}>
          <div className="flex justify-between items-center mb-4">
            <h3 className="text-xl font-bold text-white">{title}</h3>
            <button onClick={onClose} className="text-slate-400 hover:text-white">✕</button>
          </div>
          {children}
        </div>
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950 text-white">
      {/* Header */}
      <header className="border-b border-slate-800 bg-slate-900/50 backdrop-blur-xl">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-cyan-400 rounded-lg flex items-center justify-center">
                <DollarSign className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-2xl font-bold">Credbook</h1>
                <p className="text-sm text-slate-400">Lender Dashboard</p>
              </div>
            </div>
            <button className="bg-gradient-to-r from-blue-500 to-cyan-400 px-6 py-2 rounded-lg font-semibold hover:opacity-90 transition-all">
              Connect Wallet
            </button>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-6 py-8">
        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <StatCard 
            title="Total Deposits" 
            value={totalStats.totalDeposits} 
            icon={DollarSign}
            change="+5.2%"
            trend="up"
          />
          <StatCard 
            title="Your Supply" 
            value={totalStats.yourSupply} 
            icon={TrendingUp}
            change="+2.8%"
            trend="up"
          />
          <StatCard 
            title="Total Earned" 
            value={totalStats.totalEarned} 
            icon={Activity}
            change="+12.4%"
            trend="up"
          />
          <StatCard 
            title="Avg APY" 
            value={totalStats.avgAPY} 
            icon={Percent}
          />
        </div>

        {/* Tabs */}
        <div className="flex gap-4 mb-6 border-b border-slate-800">
          <button className="px-4 py-3 text-blue-400 border-b-2 border-blue-400 font-semibold">
            My Positions
          </button>
          <button className="px-4 py-3 text-slate-400 hover:text-white transition-colors">
            Orderbook
          </button>
          <button className="px-4 py-3 text-slate-400 hover:text-white transition-colors ml-auto flex items-center gap-2">
            <RefreshCw className="w-4 h-4" />
            Refresh
          </button>
        </div>

        {/* Pools Grid */}
        <div className="mb-8">
          <h2 className="text-xl font-bold mb-4">Lending Pools</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {pools.map(pool => <PoolCard key={pool.id} pool={pool} />)}
          </div>
        </div>

        {/* Orderbook Section */}
        <div className="bg-gradient-to-br from-slate-800 to-slate-900 rounded-xl p-6 border border-slate-700">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h2 className="text-xl font-bold mb-1">Live Orderbook</h2>
              <p className="text-slate-400 text-sm">Best rates from all pools (sorted by APY)</p>
            </div>
            <div className="text-right">
              <p className="text-slate-400 text-sm">Best Rate</p>
              <p className="text-2xl font-bold text-green-400">{orderbookOrders[0].rate}%</p>
            </div>
          </div>

          <div className="space-y-2">
            <div className="grid grid-cols-5 gap-4 text-sm text-slate-400 font-medium px-4 pb-2 border-b border-slate-700">
              <div>Pool</div>
              <div className="text-right">Rate (APY)</div>
              <div className="text-right">Amount</div>
              <div className="text-right">Utilization</div>
              <div></div>
            </div>
            
            {orderbookOrders.map((order, idx) => (
              <div key={order.id}>
                <div 
                  className={`grid grid-cols-5 gap-4 items-center p-4 rounded-lg transition-all cursor-pointer ${
                    idx === 0 ? 'bg-green-500/10 border border-green-500/30' : 
                    'bg-slate-800/50 hover:bg-slate-700/50'
                  }`}
                  onClick={() => setExpandedOrder(expandedOrder === order.id ? null : order.id)}
                >
                  <div className="flex items-center gap-2">
                    <div className="w-8 h-8 bg-blue-500/20 rounded-lg flex items-center justify-center">
                      <span className="text-xs font-bold text-blue-400">{order.poolId}</span>
                    </div>
                    <span className="font-medium">{order.pool}</span>
                  </div>
                  <div className="text-right">
                    <span className={`font-bold ${idx === 0 ? 'text-green-400' : 'text-white'}`}>
                      {order.rate}%
                    </span>
                  </div>
                  <div className="text-right text-slate-300">{order.amount}</div>
                  <div className="text-right">
                    <span className="text-slate-300">{order.utilization}%</span>
                  </div>
                  <div className="text-right">
                    {expandedOrder === order.id ? 
                      <ChevronUp className="w-5 h-5 text-slate-400 ml-auto" /> : 
                      <ChevronDown className="w-5 h-5 text-slate-400 ml-auto" />
                    }
                  </div>
                </div>
                
                {expandedOrder === order.id && (
                  <div className="bg-slate-800 p-4 rounded-lg mt-2 ml-4 border-l-2 border-blue-500">
                    <div className="grid grid-cols-2 gap-4 mb-3">
                      <div>
                        <p className="text-slate-400 text-sm mb-1">Simulated Utilization</p>
                        <p className="text-white font-semibold">{order.utilization}%</p>
                      </div>
                      <div>
                        <p className="text-slate-400 text-sm mb-1">Order Size</p>
                        <p className="text-white font-semibold">{order.amount}</p>
                      </div>
                    </div>
                    <button className="w-full bg-blue-500 hover:bg-blue-600 text-white py-2 rounded-lg font-medium transition-all">
                      Supply to This Pool
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Supply Modal */}
      <Modal show={showSupplyModal} onClose={() => setShowSupplyModal(false)} title={`Supply to ${selectedPool?.name}`}>
        <div className="space-y-4">
          <div>
            <label className="text-slate-400 text-sm mb-2 block">Amount (USDC)</label>
            <input 
              type="number"
              value={supplyAmount}
              onChange={(e) => setSupplyAmount(e.target.value)}
              className="w-full bg-slate-700 border border-slate-600 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-blue-500"
              placeholder="0.00"
            />
          </div>
          
          <div className="bg-slate-700/50 rounded-lg p-4 space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-slate-400">Current APY</span>
              <span className="text-white font-semibold">{selectedPool?.apy}%</span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-400">Your New Supply</span>
              <span className="text-white font-semibold">
                ${(parseFloat(selectedPool?.yourSupply.replace(/[$,]/g, '') || 0) + parseFloat(supplyAmount || 0)).toLocaleString()}
              </span>
            </div>
          </div>
          
          <button className="w-full bg-gradient-to-r from-blue-500 to-cyan-400 text-white py-3 rounded-lg font-semibold hover:opacity-90 transition-all">
            Supply USDC
          </button>
        </div>
      </Modal>

      {/* Withdraw Modal */}
      <Modal show={showWithdrawModal} onClose={() => setShowWithdrawModal(false)} title={`Withdraw from ${selectedPool?.name}`}>
        <div className="space-y-4">
          <div>
            <label className="text-slate-400 text-sm mb-2 block">Amount (USDC)</label>
            <input 
              type="number"
              value={withdrawAmount}
              onChange={(e) => setWithdrawAmount(e.target.value)}
              className="w-full bg-slate-700 border border-slate-600 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-blue-500"
              placeholder="0.00"
            />
            <button 
              onClick={() => setWithdrawAmount(selectedPool?.yourSupply.replace(/[$,]/g, ''))}
              className="text-blue-400 text-sm mt-2 hover:text-blue-300"
            >
              Max: {selectedPool?.yourSupply}
            </button>
          </div>
          
          <div className="bg-slate-700/50 rounded-lg p-4 space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-slate-400">Available to Withdraw</span>
              <span className="text-white font-semibold">{selectedPool?.yourSupply}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-400">Earned Interest</span>
              <span className="text-green-400 font-semibold">{selectedPool?.earned}</span>
            </div>
          </div>
          
          <button className="w-full bg-slate-700 hover:bg-slate-600 text-white py-3 rounded-lg font-semibold transition-all">
            Withdraw USDC
          </button>
        </div>
      </Modal>
    </div>
  );
};

export default CredbookLenderDashboard;