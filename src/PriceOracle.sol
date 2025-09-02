// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import "./interfaces/AggregatorV3interface.sol";

contract PriceOracle {
    
    /**
     * Network: Eth mainnet
     * Aggregator: ETH/USD
     * Address: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
     */
    address EthUsdFeed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    function setFeed( address ethUsd) public virtual {
        EthUsdFeed = ethUsd;
    }

    /**
     * Returns the latest answer.
     */
    function getChainlinkDataFeedLatestAnswer() public view returns (int, uint) {
        AggregatorV3Interface dataFeed = AggregatorV3Interface(EthUsdFeed);
            
        ( ,int256 answer,, uint256 updatedAt,) = dataFeed.latestRoundData();
        uint precision = dataFeed.decimals();
        require(updatedAt >= block.timestamp - 30 minutes, "Price is outdated");
        require(answer > 0, "Invalid price");
        return (answer, precision);
    }
}
