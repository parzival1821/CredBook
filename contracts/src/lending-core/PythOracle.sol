pragma solidity ^0.8.0;
 
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
 
contract PythOracle{
  IPyth pyth;
 
  /**
   * @param pythContract The address of the Pyth contract
   */
  // 0xDd24F84d36BF92C65F92307595335bdFab5Bbd21 - eth sepolia
  constructor(address pythContract) payable {
    pyth = IPyth(pythContract);
  }
 
  /**
     * This method is an example of how to interact with the Pyth contract.
     * Fetch the priceUpdate from Hermes and pass it to the Pyth contract to update the prices.
     * Add the priceUpdate argument to any method on your contract that needs to read the Pyth price.
     * See https://docs.pyth.network/price-feeds/fetch-price-updates for more information on how to fetch the priceUpdate.
 
     * @param priceUpdate The encoded data to update the contract with the latest price
     */
  function price(bytes[] calldata priceUpdate) public payable returns(int64){
    uint fee = pyth.getUpdateFee(priceUpdate);
    pyth.updatePriceFeeds{ value: fee }(priceUpdate);
 
    // Read the current price from a price feed if it is less than 60 seconds old.
    // Each price feed (e.g., ETH/USD) is identified by a price feed ID.
    // The complete list of feed IDs is available at https://docs.pyth.network/price-feeds/price-feeds
    bytes32 priceFeedId = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace; // ETH/USD , precisely what i need
    PythStructs.Price memory price = pyth.getPriceNoOlderThan(priceFeedId, 60);
    return price.price;
  }
}
