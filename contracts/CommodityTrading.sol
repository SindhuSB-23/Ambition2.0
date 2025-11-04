// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CommodityTrading is ERC20, Ownable, ReentrancyGuard {
    struct Commodity {
        uint256 id;
        string name;
        string symbol;
        uint256 totalSupply;
        uint256 currentPrice;
        uint256 lastPriceUpdate;
        bool isActive;
    }

    struct Trade {
        uint256 id;
        address trader;
        uint256 commodityId;
        bool isBuy;
        uint256 amount;
        uint256 price;
        uint256 timestamp;
    }

    mapping(uint256 => Commodity) public commodities;
    mapping(uint256 => Trade) public trades;
    mapping(address => uint256[]) public userTrades;
    mapping(address => mapping(uint256 => uint256)) public userBalances;
    
    uint256 public commodityCount;
    uint256 public tradeCount;
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 2; // 2%

    event CommodityAdded(uint256 indexed commodityId, string name, string symbol, uint256 initialPrice);
    event TradeExecuted(uint256 indexed tradeId, address indexed trader, uint256 commodityId, bool isBuy, uint256 amount, uint256 price);

    constructor() ERC20("CommodityToken", "COMM") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 * 10**18); // 1M tokens
    }

    function addCommodity(
        string memory name,
        string memory symbol,
        uint256 initialPrice,
        uint256 totalSupply
    ) external onlyOwner returns (uint256) {
        require(bytes(name).length > 0, "Name required");
        require(bytes(symbol).length > 0, "Symbol required");
        require(initialPrice > 0, "Initial price must be greater than 0");
        require(totalSupply > 0, "Total supply must be greater than 0");

        commodityCount++;
        commodities[commodityCount] = Commodity({
            id: commodityCount,
            name: name,
            symbol: symbol,
            totalSupply: totalSupply,
            currentPrice: initialPrice,
            lastPriceUpdate: block.timestamp,
            isActive: true
        });

        emit CommodityAdded(commodityCount, name, symbol, initialPrice);
        return commodityCount;
    }

    function buyCommodity(uint256 commodityId, uint256 amount) external payable nonReentrant {
        Commodity storage commodity = commodities[commodityId];
        require(commodity.isActive, "Commodity not active");
        require(amount > 0, "Amount must be greater than 0");
        require(msg.value >= amount * commodity.currentPrice, "Insufficient payment");

        tradeCount++;
        trades[tradeCount] = Trade({
            id: tradeCount,
            trader: msg.sender,
            commodityId: commodityId,
            isBuy: true,
            amount: amount,
            price: commodity.currentPrice,
            timestamp: block.timestamp
        });

        userTrades[msg.sender].push(tradeCount);
        userBalances[msg.sender][commodityId] += amount;

        // Calculate fees
        uint256 totalCost = amount * commodity.currentPrice;
        uint256 platformFee = (totalCost * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 ownerAmount = totalCost - platformFee;

        // Distribute payments
        payable(owner()).transfer(platformFee);

        // Update price (simplified price discovery)
        updatePrice(commodityId);

        emit TradeExecuted(tradeCount, msg.sender, commodityId, true, amount, commodity.currentPrice);
    }

    function sellCommodity(uint256 commodityId, uint256 amount) external nonReentrant {
        Commodity storage commodity = commodities[commodityId];
        require(commodity.isActive, "Commodity not active");
        require(amount > 0, "Amount must be greater than 0");
        require(userBalances[msg.sender][commodityId] >= amount, "Insufficient balance");

        tradeCount++;
        trades[tradeCount] = Trade({
            id: tradeCount,
            trader: msg.sender,
            commodityId: commodityId,
            isBuy: false,
            amount: amount,
            price: commodity.currentPrice,
            timestamp: block.timestamp
        });

        userTrades[msg.sender].push(tradeCount);
        userBalances[msg.sender][commodityId] -= amount;

        // Calculate payment
        uint256 totalValue = amount * commodity.currentPrice;
        uint256 platformFee = (totalValue * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 sellerAmount = totalValue - platformFee;

        // Pay seller
        payable(msg.sender).transfer(sellerAmount);

        // Update price
        updatePrice(commodityId);

        emit TradeExecuted(tradeCount, msg.sender, commodityId, false, amount, commodity.currentPrice);
    }

    function updatePrice(uint256 commodityId) internal {
        Commodity storage commodity = commodities[commodityId];
        // Simplified price update mechanism
        uint256 timeElapsed = block.timestamp - commodity.lastPriceUpdate;
        if (timeElapsed > 1 hours) {
            // Random price fluctuation for demo
            uint256 fluctuation = (block.timestamp % 10) - 5; // -5% to +5%
            commodity.currentPrice = commodity.currentPrice * (100 + fluctuation) / 100;
            commodity.lastPriceUpdate = block.timestamp;
        }
    }

    function setCommodityPrice(uint256 commodityId, uint256 newPrice) external onlyOwner {
        require(commodities[commodityId].isActive, "Commodity not active");
        require(newPrice > 0, "Price must be greater than 0");

        commodities[commodityId].currentPrice = newPrice;
        commodities[commodityId].lastPriceUpdate = block.timestamp;
    }

    function getCommodity(uint256 commodityId) external view returns (
        uint256 id,
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 currentPrice,
        uint256 lastPriceUpdate,
        bool isActive
    ) {
        Commodity storage commodity = commodities[commodityId];
        return (
            commodity.id,
            commodity.name,
            commodity.symbol,
            commodity.totalSupply,
            commodity.currentPrice,
            commodity.lastPriceUpdate,
            commodity.isActive
        );
    }

    function getTrade(uint256 tradeId) external view returns (
        uint256 id,
        address trader,
        uint256 commodityId,
        bool isBuy,
        uint256 amount,
        uint256 price,
        uint256 timestamp
    ) {
        Trade storage trade = trades[tradeId];
        return (
            trade.id,
            trade.trader,
            trade.commodityId,
            trade.isBuy,
            trade.amount,
            trade.price,
            trade.timestamp
        );
    }

    function getUserBalance(address user, uint256 commodityId) external view returns (uint256) {
        return userBalances[user][commodityId];
    }

    function getUserTrades(address user) external view returns (uint256[] memory) {
        return userTrades[user];
    }

    function getTotalCommodities() external view returns (uint256) {
        return commodityCount;
    }

    function getTotalTrades() external view returns (uint256) {
        return tradeCount;
    }

    function withdrawPlatformFees() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
