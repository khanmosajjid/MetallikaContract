const { ethers, upgrades } = require("hardhat");
let name = "METALLIKA"
let symbol = "MTLK"
let initialSupply = "10000"
let _initialVoters = ["0x82e5B489661F4041A5cA426953eb24858EBC3aB6", "0x1820B69Fa44B4F6fB4292fd8f4559A203727DB27"]
let _maxTxAmount = "100"
let _maxWalletBalance = "2000"
let launchDelay = "100"


let params = [name, symbol,18, initialSupply,"0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3", _initialVoters]

async function main() {
  const multiSigDeployer = await ethers.getContractFactory("Metallika2");
  const proxy = await upgrades.deployProxy(multiSigDeployer, params, { gasLimit: "90000000" });
  console.log("proxy", proxy?.address);
  await proxy.deployed();

  console.log(proxy.address);
  await hre.run("verify:verify", {
    address: proxy.address,
    constructorArguments: [],
  });
}

main();