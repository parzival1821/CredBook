
import { getContract } from "@wagmi/core";
import { sepolia } from "viem/chains";
import { config } from "./wagmi"; 

export const ORDERBOOK = "0x8b747A7f7015a7B2e78c9B31D37f84FCA3a88f4F";

export const POOLS = [
  "0x19c35eE719E44F8412008969F741063868492ea2",
  "0xceaf52C12E2af9B702A845812023387245ae1895",
  "0x6b4e732873153e62FccA6d1BcAc861F1e96BAa57",
  "0x9Ad831EDbe601209fa7F42b51d6466C7297F334B"
];

export const USDC = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238";
export const WETH = "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14";

export const erc20ABI = [
  "function approve(address spender, uint256 amount) public returns (bool)"
];

export const poolABI = [
  "function supply(uint256 amount, uint256 minShares, address onBehalfOf, bytes calldata) external",
  "function withdraw(uint256 shares, address onBehalfOf, address receiver) external"
];

export const orderbookABI = [
  "function matchBorrowOrder(address borrower, uint256 borrowAmount, uint256 maxRate, uint256 collateralAmount) external",
  "function fulfillRepay(address borrower, uint256 repayAmount) external",
  "function getAllOrders() external view returns (tuple(uint256 rate, uint256 amount, address pool)[])",
  "function getBorrowerPositions(address borrower) external view returns (...)",
  "function getActualDebt(address borrower) external view returns (uint256)"
];

export const getUSDC = () =>
  getContract({ address: USDC, abi: erc20ABI, chainId: sepolia.id, config });

export const getWETH = () =>
  getContract({ address: WETH, abi: erc20ABI, chainId: sepolia.id, config });

export const getPool = (index: number) =>
  getContract({ address: POOLS[index], abi: poolABI, chainId: sepolia.id, config });

export const getOrderbook = () =>
  getContract({ address: ORDERBOOK, abi: orderbookABI, chainId: sepolia.id, config });
