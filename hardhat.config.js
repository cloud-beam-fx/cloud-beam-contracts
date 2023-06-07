require("@nomicfoundation/hardhat-toolbox");
const { task } = require("hardhat/config");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
//require("@nomicfoundation/hardhat-waffle");
require("hardhat-gas-reporter");
require("dotenv").config();
const {networks} = require("./networks");

const SOLC_SETTINGS = {
  optimizer: {
    enabled: true,
    runs: 1,
  },
}

task("accounts", "prints the list of accounts", async () => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.table({address: account.address, privateKey: account.privateKey});
  }

  console.log(wallet1.privateKey);
});

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.7",
        settings: SOLC_SETTINGS,
      },
      {
        version: "0.7.0",
        settings: SOLC_SETTINGS,
      },
      {
        version: "0.6.6",
        settings: SOLC_SETTINGS,
      },
      {
        version: "0.4.24",
        settings: SOLC_SETTINGS,
      },
    ],
  },
  networks: {
    hardhat: {
      accounts: process.env.PRIVATE_KEY
        ? [
            {
              privateKey: process.env.PRIVATE_KEY,
              balance: "10000000000000000000000",
            },
          ]
        : [],
    },
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    ...networks
  }
};
