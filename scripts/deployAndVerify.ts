import { ethers, run } from 'hardhat'

const IGS_ADDRESS = process.env.IGS_ADDRESS || ''
const UNISWAP_V3_POOL_ADDRESS = process.env.UNISWAP_V3_POOL_ADDRESS || ''

async function main() {
  const defi = await ethers.getContractFactory('Defi')
  console.log('Deploying contract...')
  const contract = await defi.deploy()
  await contract.waitForDeployment()
  console.log(`Defi with deployed to ${contract.target}`)
  console.log('Wating for block confirmations...')
  // initial
  console.log('initial')
  await contract.setIGS(IGS_ADDRESS)
  console.log(`Set IGS token success! address => ${IGS_ADDRESS}`)
  await contract.setUniswapV3Pool(UNISWAP_V3_POOL_ADDRESS)
  console.log(`Set UniswapV3Pool success! address => ${UNISWAP_V3_POOL_ADDRESS}`)
  // Verify
  console.log('Verifying contract...')
  try {
    await run('verify:verify', {
      address: contract.target,
      constructorArguments: []
    })
  } catch (e) {
    if ((e as TypeError).message.toLowerCase().includes('already verified')) {
      console.log('Already Verified!')
    } else {
      console.log(e)
    }
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
