import { ethers } from 'hardhat'
import { Defi } from '../typechain-types'

describe('Defi', function () {
  let contract: Defi
  before(async function () {
    contract = await ethers.deployContract('Defi')
    await contract.waitForDeployment()
    console.log(`Defi deploy to ${contract.target}`)
  })

  describe('测试', function () {
    it('设置池地址', async function () {
      const poolAddress = '0x92f4Fd0e7BefEf4Ae88a635564bAd9b82C5b20be'
      await contract.setUniswapV3Pool(poolAddress)
    })

    it('设置igs地址', async function () {
      await contract.setIGS('0x51f9f9fF6cB2266D68c04eC289c7ABa81378a383')
    })

    it('绑定', async function () {
      const user = await ethers.getSigner('0xc86094dd1e49bc04397a4fab3d2bde4a671e89eb')
      // const [owner] = await ethers.getSigners()
      await contract.connect(user).bind('0xb728c15C35ADF40A8627a6dfA2614D8E84f03361')
      const accountInfo = await contract._accountMap(user.address)
      console.log(accountInfo)
    })

    it('股东列表', async function () {
      console.log(await contract.shareholders())
    })
  })
})
