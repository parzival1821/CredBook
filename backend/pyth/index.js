const ethers = require('ethers');
const axios = require('axios');
require('dotenv').config();

// Pyth Hermes API endpoint
const PYTH_API = 'https://hermes.pyth.network';

// ETH/USD price feed ID
const ETH_USD_PRICE_ID = '0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace';

// Contract addresses (from deployment)
const PYTH_ORACLE_ADDRESS = process.env.PYTH_ORACLE_ADDRESS;
const ORDERBOOK_ADDRESS = process.env.ORDERBOOK_ADDRESS;

// RPC and private key
const provider = new ethers.providers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
const wallet = new ethers.Wallet(process.env.UPDATER_PRIVATE_KEY, provider);

// ABI for PythOracle
const PYTH_ORACLE_ABI = [
  'function updatePrice(bytes[] calldata priceUpdate) external payable',
  'function price() external view returns (uint256)',
  'function getLatestPrice() external view returns (int64 price, uint64 publishTime)'
];

const pythOracle = new ethers.Contract(PYTH_ORACLE_ADDRESS, PYTH_ORACLE_ABI, wallet);

/**
 * Fetch price update data from Pyth Hermes API
 */
async function getPriceUpdateData() {
  try {
    const response = await axios.get(`${PYTH_API}/api/latest_vaas`, {
      params: {
        ids: [ETH_USD_PRICE_ID]
      }
    });
    
    return response.data.map(data => '0x' + Buffer.from(data, 'base64').toString('hex'));
  } catch (error) {
    console.error('Error fetching price data:', error.message);
    throw error;
  }
}

/**
 * Update price on-chain
 */
async function updatePrice() {
  try {
    console.log('Fetching latest price data from Pyth...');
    const priceUpdateData = await getPriceUpdateData();
    
    console.log('Updating price on-chain...');
    const tx = await pythOracle.updatePrice(priceUpdateData, {
      value: ethers.utils.parseEther('0.001'), // Small fee for Pyth update
      gasLimit: 500000
    });
    
    console.log(`Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`Price updated! Gas used: ${receipt.gasUsed.toString()}`);
    
    // Get the updated price
    const price = await pythOracle.price();
    const priceFormatted = ethers.utils.formatUnits(price, 36);
    console.log(`Current ETH/USD price: $${parseFloat(priceFormatted).toFixed(2)}`);
    
    return receipt;
  } catch (error) {
    console.error('Error updating price:', error.message);
    throw error;
  }
}

/**
 * Check if price needs updating
 */
async function checkAndUpdate() {
  try {
    const [price, publishTime] = await pythOracle.getLatestPrice();
    const now = Math.floor(Date.now() / 1000);
    const age = now - publishTime;
    
    console.log(`Price age: ${age} seconds`);
    
    // Update if price is older than 30 seconds
    if (age > 30) {
      console.log('Price is stale, updating...');
      await updatePrice();
    } else {
      console.log('Price is fresh, no update needed');
    }
  } catch (error) {
    console.error('Error checking price:', error.message);
  }
}

/**
 * Main loop - update price every minute
 */
async function main() {
  console.log('Starting Pyth price updater...');
  console.log(`Oracle: ${PYTH_ORACLE_ADDRESS}`);
  console.log(`Network: Sepolia\n`);
  
  // Initial update
  await updatePrice();
  
  // Update every 60 seconds
  setInterval(async () => {
    await checkAndUpdate();
  }, 60000);
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n Shutting down price updater...');
  process.exit(0);
});

main().catch(console.error);