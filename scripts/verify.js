const { ethers, upgrades } = require("hardhat");

async function main() {

    await hre.run("verify:verify", {
        address: "0xfBbcD1D0D9A213BdfE9b35FB8De200814ca348BD",
        constructorArguments: []
    });
}

// Call the main function and catch if there is any error
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });