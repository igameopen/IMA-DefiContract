import { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"

require("dotenv").config()

const PRIVATE_KEY = process.env.PRIVATE_KEY || ''
const API_KEY = process.env.API_KEY || ''

console.log(`PRIVATE_KEY => ${PRIVATE_KEY}`)
console.log(`API_KEY => ${API_KEY}`)

const config: HardhatUserConfig = {
  solidity: {
    version: "0.7.6",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    arbitrumOne: {
      url: "https://arb1.arbitrum.io/rpc",
      accounts: [PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: {
      arbitrumOne: API_KEY
    }
  }
};

export default config;
