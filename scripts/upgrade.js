const { ethers, upgrades } = require("hardhat");

async function main() {
    // const ProxyContract = await ethers.getContractFactory("EQXTokenV1");
    const proxyAddress = "0xbF3b167A3bF786fE01D1Bb2Dc4C319024Bf5d9A5"; // Specify the address of your existing proxy contract
    const newImplementation = await ethers.getContractFactory("Metallika2");

    // Upgrade the proxy contract
    const upgradedProxy = await upgrades.upgradeProxy(proxyAddress, newImplementation);
    console.log("Proxy contract upgraded:", upgradedProxy.address);
    await hre.run("verify:verify", {
      address: upgradedProxy.address,
      constructorArguments: [],
    });
}

main();
