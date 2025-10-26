'use client'
import React, { useState, useEffect } from 'react';
import { Search, ChevronDown, Wallet, TrendingUp, Shield, Clock, AlertCircle, RefreshCw } from 'lucide-react';

// Contract ABIs (minimal - only functions we need)
const ORDERBOOK_ABI = [
  "function matchBorrowOrder(address borrower, uint256 amount, uint256 maxRate, uint256 collateralAmount) external",
  "function fulfillRepay(address borrower, uint256 amount) external",
  "function getAllOrders() external view returns (tuple(address pool, uint256 poolId, uint256 amount, uint256 rate, uint256 utilization)[])",
  "function getBorrowerPositions(address borrower) external view returns (tuple(address pool, uint256 poolId, uint256 amount, uint256 timestamp)[])",
  "function getActualDebt(address borrower) external view returns (uint256)",
  "function refreshOrderbook() external"
];

const ERC20_ABI = [
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function allowance(address owner, address spender) external view returns (uint256)",
  "function balanceOf(address account) external view returns (uint256)"
];

const POOL_ABI = [
  "function market(uint256) external view returns (uint128 totalSupplyAssets, uint128 totalSupplyShares, uint128 totalBorrowAssets, uint128 totalBorrowShares, uint128 lastUpdate, uint128 fee)"
];

// Contract addresses on Sepolia
const ADDRESSES = {
  orderbook: '0xaA3160EEB23De34ea20Ab7E837F1886224904A1F',
  usdc: '0x55683adB8A326cc7eb0C035f3c64bbf1272c7B0B',
  weth: '0x52a3d539AC082CcdBae14cd2490543Ccb2C50c58',
  pools: [
    '0x9804Be3066EbbC26b97fe3e223710747314A529f',
    '0xf35498dDbA364495b44Aafb67C7C3e5bc60300a2',
    '0x3dC785aa7d88a90cf7a1F312d0B17BFD9AA7e0e2',
    '0x75288A8156DB6ba8eA902dc318B80FA551F5421E'
  ]
};

export default function BorrowerDashboard() {
  // Wallet state
  const [account, setAccount] = useState<string | null>(null);
  const [isConnecting, setIsConnecting] = useState(false);
  const [provider, setProvider] = useState<any>(null);
  const [signer, setSigner] = useState<any>(null);

  // UI state
  const [selectedCollateral, setSelectedCollateral] = useState('WETH');
  const [orderType, setOrderType] = useState<'market' | 'limit'>('market');
  const [collateralAmount, setCollateralAmount] = useState('');
  const [borrowAmount, setBorrowAmount] = useState('');
  const [limitRate, setLimitRate] = useState('');
  const [selectedPool, setSelectedPool] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [txStatus, setTxStatus] = useState<string | null>(null);

  // Data state
  const [wethBalance, setWethBalance] = useState('0');
  const [usdcBalance, setUsdcBalance] = useState('0');
  const [orders, setOrders] = useState<any[]>([]);
  const [positions, setPositions] = useState<any[]>([]);
  const [totalBorrowed, setTotalBorrowed] = useState('0');
  const [actualDebt, setActualDebt] = useState('0');
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Connect wallet
  const connectWallet = async () => {
    if (typeof window.ethereum === 'undefined') {
      alert('Please install MetaMask to use this application');
      return;
    }

    setIsConnecting(true);
    try {
      // Request account access
      const accounts = await window.ethereum.request({ 
        method: 'eth_requestAccounts' 
      });
      
      // Check if on Sepolia
      const chainId = await window.ethereum.request({ method: 'eth_chainId' });
      if (chainId !== '0xaa36a7') { // Sepolia chainId
        try {
          await window.ethereum.request({
            method: 'wallet_switchEthereumChain',
            params: [{ chainId: '0xaa36a7' }],
          });
        } catch (error: any) {
          if (error.code === 4902) {
            alert('Please add Sepolia network to MetaMask');
          }
          throw error;
        }
      }

      const ethers = (window as any).ethers;
      const web3Provider = new ethers.BrowserProvider(window.ethereum);
      const web3Signer = await web3Provider.getSigner();
      
      setAccount(accounts[0]);
      setProvider(web3Provider);
      setSigner(web3Signer);
      
      // Load initial data
      await loadData(accounts[0], web3Provider, web3Signer);
    } catch (error) {
      console.error('Error connecting wallet:', error);
      alert('Failed to connect wallet');
    } finally {
      setIsConnecting(false);
    }
  };

  // Load all data
  const loadData = async (userAddress: string, web3Provider: any, web3Signer: any) => {
    try {
      const ethers = (window as any).ethers;
      
      // Load balances
      const wethContract = new ethers.Contract(ADDRESSES.weth, ERC20_ABI, web3Provider);
      const usdcContract = new ethers.Contract(ADDRESSES.usdc, ERC20_ABI, web3Provider);
      
      const wethBal = await wethContract.balanceOf(userAddress);
      const usdcBal = await usdcContract.balanceOf(userAddress);
      
      setWethBalance(ethers.formatEther(wethBal));
      setUsdcBalance(ethers.formatUnits(usdcBal, 6));
      
      // Load orderbook data
      const orderbookContract = new ethers.Contract(ADDRESSES.orderbook, ORDERBOOK_ABI, web3Provider);
      
      const allOrders = await orderbookContract.getAllOrders();
      const userPositions = await orderbookContract.getBorrowerPositions(userAddress);
      const debt = await orderbookContract.getActualDebt(userAddress);
      
      setOrders(allOrders);
      setPositions(userPositions);
      setActualDebt(ethers.formatUnits(debt, 6));
      
      // Calculate total borrowed from positions
      const total = userPositions.reduce((sum: bigint, pos: any) => sum + pos.amount, 0n);
      setTotalBorrowed(ethers.formatUnits(total, 6));
      
    } catch (error) {
      console.error('Error loading data:', error);
    }
  };

  // Refresh orderbook
  const refreshOrderbook = async () => {
    if (!signer) return;
    
    setIsRefreshing(true);
    try {
      const ethers = (window as any).ethers;
      const orderbookContract = new ethers.Contract(ADDRESSES.orderbook, ORDERBOOK_ABI, signer);
      
      const tx = await orderbookContract.refreshOrderbook();
      await tx.wait();
      
      // Reload data
      await loadData(account!, provider, signer);
      setTxStatus('Orderbook refreshed successfully');
      setTimeout(() => setTxStatus(null), 3000);
    } catch (error) {
      console.error('Error refreshing orderbook:', error);
      alert('Failed to refresh orderbook');
    } finally {
      setIsRefreshing(false);
    }
  };

  // Create borrow order
  const handleCreateOrder = async () => {
    if (!account || !signer || !collateralAmount || !borrowAmount) {
      alert('Please fill in all required fields and connect wallet');
      return;
    }

    setIsLoading(true);
    setTxStatus('Preparing transaction...');

    try {
      const ethers = (window as any).ethers;
      const orderbookContract = new ethers.Contract(ADDRESSES.orderbook, ORDERBOOK_ABI, signer);
      const wethContract = new ethers.Contract(ADDRESSES.weth, ERC20_ABI, signer);
      
      // Parse amounts
      const collateralWei = ethers.parseEther(collateralAmount);
      const borrowWei = ethers.parseUnits(borrowAmount, 6);
      
      console.log('Collateral (WETH):', collateralAmount, 'Wei:', collateralWei.toString());
      console.log('Borrow (USDC):', borrowAmount, 'Wei:', borrowWei.toString());
      
      // Check WETH balance
      setTxStatus('Checking WETH balance...');
      const wethBal = await wethContract.balanceOf(account);
      console.log('WETH Balance:', ethers.formatEther(wethBal));
      
      if (wethBal < collateralWei) {
        alert(`Insufficient WETH balance. You have ${ethers.formatEther(wethBal)} WETH but need ${collateralAmount} WETH`);
        setTxStatus(null);
        setIsLoading(false);
        return;
      }
      
      // Calculate max rate (convert % to per-second WAD)
      let maxRateWad;
      if (orderType === 'limit' && limitRate) {
        // Convert annual % to per-second rate in WAD
        const annualRate = parseFloat(limitRate) / 100;
        const perSecondRate = annualRate / (365.25 * 24 * 60 * 60);
        maxRateWad = ethers.parseUnits(perSecondRate.toFixed(18), 18);
      } else {
        // Market order - accept very high rate (1000% APR as max)
        maxRateWad = ethers.parseUnits('0.0000003170979', 18); // ~1000% APR
      }
      
      console.log('Max Rate (WAD):', maxRateWad.toString());
      
      // Check if orderbook has orders
      setTxStatus('Checking available orders...');
      const availableOrders = await orderbookContract.getAllOrders();
      console.log('Available orders:', availableOrders.length);
      
      
      // Check if first order rate is within max
      const firstOrderRate = availableOrders[0].rate;
      console.log('Best available rate:', firstOrderRate.toString());
      
      if (firstOrderRate > maxRateWad) {
        const firstRateAPR = formatRate(firstOrderRate);
        const maxRateAPR = orderType === 'limit' ? limitRate : '1000';
        alert(`Best available rate is ${firstRateAPR}% APR, which exceeds your max rate of ${maxRateAPR}% APR`);
        setTxStatus(null);
        setIsLoading(false);
        return;
      }
      
      // Calculate total available liquidity
      let totalLiquidity = 0n;
      for (const order of availableOrders) {
        if (order.rate <= maxRateWad) {
          totalLiquidity += order.amount;
        }
      }
      console.log('Total available liquidity:', ethers.formatUnits(totalLiquidity, 6), 'USDC');
      
      if (totalLiquidity < borrowWei) {
        alert(`Insufficient liquidity. Available: ${ethers.formatUnits(totalLiquidity, 6)} USDC, Requested: ${borrowAmount} USDC`);
        setTxStatus(null);
        setIsLoading(false);
        return;
      }
      
      // Check allowance
      setTxStatus('Checking WETH allowance...');
      const allowance = await wethContract.allowance(account, ADDRESSES.orderbook);
      console.log('Current allowance:', ethers.formatEther(allowance));
      
      if (allowance < collateralWei) {
        setTxStatus('Approving WETH... (confirm in wallet)');
        const approveTx = await wethContract.approve(ADDRESSES.orderbook, ethers.MaxUint256);
        setTxStatus('Waiting for approval confirmation...');
        await approveTx.wait();
        setTxStatus('WETH approved!');
      }
      
      // Execute borrow
      setTxStatus('Creating borrow order... (confirm in wallet)');
      console.log('Calling matchBorrowOrder with:', {
        borrower: account,
        amount: borrowWei.toString(),
        maxRate: maxRateWad.toString(),
        collateral: collateralWei.toString()
      });
      
      const tx = await orderbookContract.matchBorrowOrder(
        account,
        borrowWei,
        maxRateWad,
        collateralWei
      );
      
      setTxStatus('Waiting for confirmation...');
      const receipt = await tx.wait();
      console.log('Transaction receipt:', receipt);
      
      setTxStatus('Success! Order created ✓');
      
      // Reload data
      await loadData(account, provider, signer);
      
      // Clear form
      setCollateralAmount('');
      setBorrowAmount('');
      setLimitRate('');
      
      setTimeout(() => setTxStatus(null), 5000);
    } catch (error: any) {
      console.error('Error creating order:', error);
      
      // Parse error message
      let errorMsg = 'Transaction failed';
      
      if (error.message?.includes('user rejected')) {
        errorMsg = 'Transaction rejected by user';
      } else if (error.reason) {
        errorMsg = error.reason;
      } else if (error.data?.message) {
        errorMsg = error.data.message;
      } else if (error.message) {
        errorMsg = error.message;
      }
      
      // Check for common contract errors
      if (errorMsg.includes('No orders within max rate')) {
        errorMsg = 'No orders available at your requested rate. Try increasing your max rate or use a market order.';
      } else if (errorMsg.includes('Could not fill entire order')) {
        errorMsg = 'Insufficient liquidity to fill your order. Try borrowing a smaller amount.';
      } else if (errorMsg.includes('Amount must be > 0')) {
        errorMsg = 'Borrow amount must be greater than 0';
      }
      
      alert(`Failed to create order: ${errorMsg}`);
      setTxStatus(null);
    } finally {
      setIsLoading(false);
    }
  };

  // Repay debt
  const handleRepay = async () => {
    if (!account || !signer || actualDebt === '0') {
      alert('No debt to repay');
      return;
    }

    const repayAmount = prompt('Enter amount to repay (USDC):');
    if (!repayAmount) return;

    setIsLoading(true);
    setTxStatus('Preparing repayment...');

    try {
      const ethers = (window as any).ethers;
      const orderbookContract = new ethers.Contract(ADDRESSES.orderbook, ORDERBOOK_ABI, signer);
      const usdcContract = new ethers.Contract(ADDRESSES.usdc, ERC20_ABI, signer);
      
      const repayWei = ethers.parseUnits(repayAmount, 6);
      
      // Check allowance
      setTxStatus('Checking USDC allowance...');
      const allowance = await usdcContract.allowance(account, ADDRESSES.orderbook);
      
      if (allowance < repayWei) {
        setTxStatus('Approving USDC...');
        const approveTx = await usdcContract.approve(ADDRESSES.orderbook, ethers.MaxUint256);
        await approveTx.wait();
      }
      
      // Execute repay
      setTxStatus('Processing repayment...');
      const tx = await orderbookContract.fulfillRepay(account, repayWei);
      
      setTxStatus('Waiting for confirmation...');
      await tx.wait();
      
      setTxStatus('Success! Debt repaid');
      
      // Reload data
      await loadData(account, provider, signer);
      
      setTimeout(() => setTxStatus(null), 5000);
    } catch (error: any) {
      console.error('Error repaying:', error);
      const errorMsg = error.reason || error.message || 'Transaction failed';
      alert(`Failed to repay: ${errorMsg}`);
      setTxStatus(null);
    } finally {
      setIsLoading(false);
    }
  };

  // Format rate from WAD to APR %
  const formatRate = (rateWad: bigint) => {
    if (!rateWad) return '0.00';
    const ethers = (window as any).ethers;
    const perSecond = parseFloat(ethers.formatUnits(rateWad, 18));
    const apr = perSecond * 365.25 * 24 * 60 * 60 * 100;
    return apr.toFixed(2);
  };

  // Auto-refresh data every 30 seconds
  useEffect(() => {
    if (account && provider && signer) {
      const interval = setInterval(() => {
        loadData(account, provider, signer);
      }, 30000);
      return () => clearInterval(interval);
    }
  }, [account, provider, signer]);

  // Load ethers from CDN
  useEffect(() => {
    const script = document.createElement('script');
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/ethers/6.7.0/ethers.umd.min.js';
    script.async = true;
    document.body.appendChild(script);
    return () => {
      document.body.removeChild(script);
    };
  }, []);

  const collateralOptions = ['WETH'];

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
              {account && (
                <button
                  onClick={refreshOrderbook}
                  disabled={isRefreshing}
                  className="flex items-center gap-2 rounded-full bg-white/5 px-3 py-2 text-sm text-white backdrop-blur-sm hover:bg-white/10 disabled:opacity-50"
                >
                  <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
                  Refresh
                </button>
              )}
              {account ? (
                <div className="flex items-center gap-2 rounded-full bg-white/5 px-3 py-2 text-sm text-white backdrop-blur-sm">
                  <div className="h-6 w-6 rounded-full bg-gradient-to-br from-blue-400 to-purple-500" />
                  <span>{account.slice(0, 6)}...{account.slice(-4)}</span>
                </div>
              ) : (
                <button
                  onClick={connectWallet}
                  disabled={isConnecting}
                  className="flex items-center gap-2 rounded-full bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
                >
                  <Wallet className="h-4 w-4" />
                  {isConnecting ? 'Connecting...' : 'Connect Wallet'}
                </button>
              )}
            </div>
          </div>
        </div>
      </nav>

      {/* Transaction Status */}
      {txStatus && (
        <div className="mx-auto max-w-7xl px-4 py-3 sm:px-6 lg:px-8">
          <div className="rounded-lg bg-blue-500/20 border border-blue-500/50 px-4 py-3 text-sm text-blue-200 flex items-center gap-2">
            <AlertCircle className="h-4 w-4" />
            {txStatus}
          </div>
        </div>
      )}

      {/* Main Content */}
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        {/* Stats */}
        <div className="mb-8 grid grid-cols-1 gap-4 md:grid-cols-4">
          <div className="rounded-xl bg-white/5 p-6 backdrop-blur-sm border border-white/10">
            <div className="flex items-center gap-3 mb-2">
              <div className="rounded-lg bg-blue-500/20 p-2">
                <TrendingUp className="h-5 w-5 text-blue-400" />
              </div>
              <span className="text-sm text-gray-400">Actual Debt</span>
            </div>
            <p className="text-3xl font-bold text-white">${parseFloat(actualDebt).toFixed(2)}</p>
            <p className="text-sm text-gray-500 mt-1">Principal: ${parseFloat(totalBorrowed).toFixed(2)}</p>
          </div>
          <div className="rounded-xl bg-white/5 p-6 backdrop-blur-sm border border-white/10">
            <div className="flex items-center gap-3 mb-2">
              <div className="rounded-lg bg-purple-500/20 p-2">
                <Shield className="h-5 w-5 text-purple-400" />
              </div>
              <span className="text-sm text-gray-400">WETH Balance</span>
            </div>
            <p className="text-3xl font-bold text-white">{parseFloat(wethBalance).toFixed(4)}</p>
            <p className="text-sm text-gray-500 mt-1">Available collateral</p>
          </div>
          <div className="rounded-xl bg-white/5 p-6 backdrop-blur-sm border border-white/10">
            <div className="flex items-center gap-3 mb-2">
              <div className="rounded-lg bg-green-500/20 p-2">
                <Clock className="h-5 w-5 text-green-400" />
              </div>
              <span className="text-sm text-gray-400">USDC Balance</span>
            </div>
            <p className="text-3xl font-bold text-white">${parseFloat(usdcBalance).toFixed(2)}</p>
            <p className="text-sm text-gray-500 mt-1">For repayment</p>
          </div>
          <div className="rounded-xl bg-white/5 p-6 backdrop-blur-sm border border-white/10">
            <div className="flex items-center gap-3 mb-2">
              <div className="rounded-lg bg-orange-500/20 p-2">
                <Clock className="h-5 w-5 text-orange-400" />
              </div>
              <span className="text-sm text-gray-400">Active Positions</span>
            </div>
            <p className="text-3xl font-bold text-white">{positions.length}</p>
            {parseFloat(actualDebt) > 0 && (
              <button
                onClick={handleRepay}
                disabled={isLoading}
                className="mt-2 text-sm text-orange-400 hover:text-orange-300 disabled:opacity-50"
              >
                Repay Debt →
              </button>
            )}
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
                    step="0.01"
                    className="w-full rounded-lg bg-white/5 border border-white/10 px-4 py-3 text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50"
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-gray-400">
                    {selectedCollateral}
                  </span>
                </div>
                <p className="mt-1 text-xs text-gray-500">Balance: {parseFloat(wethBalance).toFixed(4)} WETH</p>
              </div>

              {/* Borrow Amount */}
              <div className="mb-4">
                <label className="mb-2 block text-sm font-medium text-gray-300">Borrow Amount (USDC)</label>
                <input
                  type="number"
                  value={borrowAmount}
                  onChange={(e) => setBorrowAmount(e.target.value)}
                  placeholder="0.00"
                  step="0.01"
                  className="w-full rounded-lg bg-white/5 border border-white/10 px-4 py-3 text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50"
                />
              </div>

              {/* Limit Rate (only for limit orders) */}
              {orderType === 'limit' && (
                <div className="mb-6">
                  <label className="mb-2 block text-sm font-medium text-gray-300">Max APR (%)</label>
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
                disabled={isLoading || !account}
                className="w-full rounded-lg bg-gradient-to-r from-blue-600 to-blue-700 py-3 font-medium text-white hover:from-blue-700 hover:to-blue-800 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
              >
                {isLoading ? 'Processing...' : !account ? 'Connect Wallet First' : 'Create Order'}
              </button>

              <p className="mt-3 text-center text-xs text-gray-400">
                Orders are matched with best available rates
              </p>
            </div>
          </div>

          {/* Available Orders */}
          <div className="lg:col-span-2">
            <div className="rounded-xl bg-white/5 p-6 backdrop-blur-sm border border-white/10">
              <div className="mb-6 flex items-center justify-between">
                <h2 className="text-xl font-bold text-white">Available Orders ({orders.length})</h2>
                <div className="text-sm text-gray-400">
                  Best rate: {orders.length > 0 ? `${formatRate(orders[0].rate)}% APR` : 'N/A'}
                </div>
              </div>

              <div className="space-y-3 max-h-[600px] overflow-y-auto">
                {orders.length === 0 ? (
                  <div className="text-center py-12 text-gray-400">
                    <p>No orders available</p>
                    <p className="text-sm mt-2">Connect wallet and refresh to load orders</p>
                  </div>
                ) : (
                  orders.map((order, idx) => (
                    <div
                      key={idx}
                      className="rounded-lg border border-white/10 bg-white/5 p-4 hover:border-white/20 transition-all"
                    >
                      <div className="flex items-center justify-between mb-3">
                        <div className="flex items-center gap-3">
                          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gradient-to-br from-blue-400 to-purple-500 text-sm font-bold text-white">
                            #{idx + 1}
                          </div>
                          <div>
                            <h3 className="font-semibold text-white">Pool #{order.poolId.toString()}</h3>
                            <p className="text-xs text-gray-400">{order.pool.slice(0, 10)}...</p>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="text-lg font-bold text-green-400">{formatRate(order.rate)}%</p>
                          <p className="text-xs text-gray-500">APR</p>
                        </div>
                      </div>
                      <div className="grid grid-cols-2 gap-4 border-t border-white/10 pt-3">
                        <div>
                          <p className="text-xs text-gray-500">Liquidity</p>
                          <p className="text-sm font-medium text-white">
                            ${(Number(order.amount) / 1e6).toFixed(2)}
                          </p>
                        </div>
                        <div>
                          <p className="text-xs text-gray-500">Utilization</p>
                          <p className="text-sm font-medium text-white">
                            {((Number(order.utilization) / 1e18) * 100).toFixed(1)}%
                          </p>
                        </div>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Active Positions */}
        {positions.length > 0 && (
          <div className="mt-6">
            <div className="rounded-xl bg-white/5 p-6 backdrop-blur-sm border border-white/10">
              <h2 className="mb-6 text-xl font-bold text-white">Your Active Positions ({positions.length})</h2>
              
              <div className="space-y-3">
                {positions.map((pos, idx) => {
                  const borrowedUSDC = Number(pos.amount) / 1e6;
                  const timestamp = new Date(Number(pos.timestamp) * 1000);
                  
                  return (
                    <div
                      key={idx}
                      className="rounded-lg border border-white/10 bg-white/5 p-4"
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gradient-to-br from-orange-400 to-red-500 text-sm font-bold text-white">
                            #{idx + 1}
                          </div>
                          <div>
                            <h3 className="font-semibold text-white">Pool #{pos.poolId.toString()}</h3>
                            <p className="text-xs text-gray-400">{pos.pool.slice(0, 16)}...</p>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="text-lg font-bold text-orange-400">${borrowedUSDC.toFixed(2)}</p>
                          <p className="text-xs text-gray-500">Borrowed</p>
                        </div>
                      </div>
                      <div className="mt-3 border-t border-white/10 pt-3">
                        <p className="text-xs text-gray-500">
                          Opened: {timestamp.toLocaleDateString()} {timestamp.toLocaleTimeString()}
                        </p>
                      </div>
                    </div>
                  );
                })}
              </div>
              
              <div className="mt-6 rounded-lg bg-orange-500/10 border border-orange-500/30 p-4">
                <div className="flex items-start gap-3">
                  <AlertCircle className="h-5 w-5 text-orange-400 flex-shrink-0 mt-0.5" />
                  <div className="flex-1">
                    <p className="text-sm font-medium text-orange-200">
                      Total Debt Including Interest: ${parseFloat(actualDebt).toFixed(2)}
                    </p>
                    <p className="text-xs text-orange-300/70 mt-1">
                      Principal: ${parseFloat(totalBorrowed).toFixed(2)} | 
                      Interest Accrued: ${(parseFloat(actualDebt) - parseFloat(totalBorrowed)).toFixed(2)}
                    </p>
                    <button
                      onClick={handleRepay}
                      disabled={isLoading}
                      className="mt-3 rounded-lg bg-orange-500 px-4 py-2 text-sm font-medium text-white hover:bg-orange-600 disabled:opacity-50"
                    >
                      Repay Debt
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}