## Setup

### Contracts
- `cd contracts && forge install`

### Frontend
- (pls fill this)


Note : Lets create separate `package.json` files for backend and frontend inside their respective folders


## Addresses for integration
  Orderbook: 0x8b747A7f7015a7B2e78c9B31D37f84FCA3a88f4F
  
  LinearIRM1: 0x5c1409dE9584B5f20677E1112B9508c9975dc6Bb
  LinearIRM2: 0x0B89a6995adaA6f1996e0D48257094A02e0124c5
  KinkIRM1: 0xF825E3Af429cC4833A7AfC69312eE8Baf3767D08
  KinkIRM2: 0xb1317b649181ef1dC6c01F27f5e8E5C00D735E2f
  
  Pool 0: 0x19c35eE719E44F8412008969F741063868492ea2
  Pool 1: 0xceaf52C12E2af9B702A845812023387245ae1895
  Pool 2: 0x6b4e732873153e62FccA6d1BcAc861F1e96BAa57
  Pool 3: 0x9Ad831EDbe601209fa7F42b51d6466C7297F334B


  SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
  SEPOLIA_WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;


  these contracts are deployed and verified on ethereum sepolia


  Integrate just like the following
  ```
    // Only need Orderbook + token addresses!

    // 1. LENDERS - Supply to pools directly
    await usdc.approve(pool0Address, amount);
    await pool0.supply(1, amount, 0, userAddress, "0x");

    // 2. BORROWERS - Use orderbook
    await weth.approve(orderbookAddress, collateralAmount);
    await orderbook.matchBorrowOrder(userAddress, borrowAmount, maxRate, collateralAmount);

    // 3. REPAY
    await usdc.approve(orderbookAddress, repayAmount);
    await orderbook.fulfillRepay(userAddress, repayAmount);

    // 4. VIEW FUNCTIONS
    const orders = await orderbook.getAllOrders();
    const positions = await orderbook.getBorrowerPositions(userAddress);
    const actualDebt = await orderbook.getActualDebt(userAddress);
```


Please refer `contracts/frontend-package` for integration