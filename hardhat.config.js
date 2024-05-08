require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@openzeppelin/hardhat-upgrades");

module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1200,
      },
    },
  },
  networks: {
    mumbai: {
      url: "https://polygon-mumbai.g.alchemy.com/v2/rfCruuBJ6-ND7sPx8qfywX0PjKWcmIQq",
      accounts: [
        "",
      ],
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s2.binance.org:8545/",
      chainId: 97,
      // gasLimit: 500000,
      accounts: [
        "",
      ],
    },
    smartchain: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      // gasLimit: 500000,
      accounts: [
        "",
      ],
    },
  },
  etherscan: {
    apiKey: "MF2AM8D1Q77SX1TTFACVHMUKUC8BN4GB6Y",
  },
};

//mumbai api key - NET91B9KDU24AS39FRIKRDNYIQ9UUYJ51K
// bsc api key - MF2AM8D1Q77SX1TTFACVHMUKUC8BN4GB6Y
