const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying Commodity Trading contract with account:", deployer.address);

  const CommodityTrading = await hre.ethers.getContractFactory("CommodityTrading");
  const commodityTrading = await CommodityTrading.deploy();

  await commodityTrading.deployed();

  console.log("Commodity Trading deployed to:", commodityTrading.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
