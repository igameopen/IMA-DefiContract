import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'

require('dotenv').config()

const PRIVATE_KEY = process.env.PRIVATE_KEY || ''
const API_KEY = process.env.API_KEY || ''

// console.log(`PRIVATE_KEY => ${PRIVATE_KEY}`)
// console.log(`API_KEY => ${API_KEY}`)

const config: HardhatUserConfig = {
  defaultNetwork: 'localhost',
  solidity: {
    version: '0.7.6',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      forking: {
        url: 'https://arb1.arbitrum.io/rpc'
        // blockNumber: 108391683
      }
    },
    // arbitrumOne: {
    //   url: "https://arb1.arbitrum.io/rpc",
    //   accounts: [PRIVATE_KEY]
    // }
    arbitrumGoerli: {
      url: 'https://goerli-rollup.arbitrum.io/rpc',
      chainId: 421613,
      accounts: [PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: {
      arbitrumOne: API_KEY
    }
  },
  mocha: {
    timeout: 400000
  }
}

export default config
