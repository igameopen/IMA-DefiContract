import { ethers } from 'hardhat'

async function main() {
  const Defi = await ethers.getContractFactory('Defi')
  const contract = await Defi.deploy()

  contract.waitForDeployment()

  console.log(`Defi with deployed to ${contract.target}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
