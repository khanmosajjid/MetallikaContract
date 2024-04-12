const { ethers, upgrades } = require("hardhat");

async function main() {
    // const ProxyContract = await ethers.getContractFactory("EQXTokenV1");
    const proxyAddress = "0x649C5751Ab5Fe8df311f80f5fc2fBb5Ce67EE04F"; // Specify the address of your existing proxy contract
    const newImplementation = await ethers.getContractFactory("Metallika2");

    // Upgrade the proxy contract
    const upgradedProxy = await upgrades.upgradeProxy(proxyAddress, newImplementation);
    console.log("Proxy contract upgraded:", upgradedProxy.address);
}

main();
