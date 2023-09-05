import { ethers } from 'hardhat'
import { time } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { Defi, INonfungiblePositionManager, ERC20Token, IWETH9, IUniswapV3Factory } from '../typechain-types'
import { expect } from 'chai'
import { getMinTick, getMaxTick } from './shared/ticks'
import { encodePriceSqrt } from './shared/encodePriceSprt'

describe('Defi', function () {
  let defi: Defi
  let positionManager: INonfungiblePositionManager
  let igs: ERC20Token
  let weth: IWETH9
  let owner: HardhatEthersSigner
  let factory: IUniswapV3Factory

  const amountIGSToMint = ethers.parseEther('100000')
  const amountETHToMint = ethers.parseEther('100')

  before(async function () {
    defi = await ethers.deployContract('Defi')
    await defi.waitForDeployment()
    console.log(`Defi deploy to ${defi.target}`)

    igs = await ethers.deployContract('ERC20Token')
    await igs.waitForDeployment()
    console.log(`IGS deploy to ${igs.target}`)

    positionManager = await ethers.getContractAt(
      'INonfungiblePositionManager',
      '0xC36442b4a4522E871399CD717aBDD847Ab11FE88'
    )

    weth = await ethers.getContractAt('IWETH9', '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1')

    factory = await ethers.getContractAt('IUniswapV3Factory', '0x1F98431c8aD98523631AE4a59f267346ea31F984')

    const [signer] = await ethers.getSigners()
    owner = signer
  })

  describe('init uniswap v3 pool', function () {
    it('WETH deposit', async function () {
      await weth.deposit({ value: amountETHToMint })
      expect(await weth.balanceOf(owner.address)).to.eq(amountETHToMint)
    })

    it('approve PositionManager', async function () {
      await igs.approve(positionManager.target, amountIGSToMint)
      await weth.approve(positionManager.target, amountETHToMint)
    })

    it('new pool', async function () {
      await positionManager.createAndInitializePoolIfNecessary(
        igs.target,
        weth.target,
        3000,
        encodePriceSqrt(amountIGSToMint, amountETHToMint)
      )
    })

    it('new positit', async function () {
      // int24 internal constant MIN_TICK = -887272;
      // /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
      // int24 internal constant MAX_TICK = -MIN_TICK;
      const timestamp = (await time.latest()) + 10
      const param: INonfungiblePositionManager.MintParamsStruct = {
        token0: igs.target,
        token1: weth.target,
        fee: 3000,
        tickLower: getMinTick(60),
        tickUpper: getMaxTick(60),
        amount0Desired: amountIGSToMint,
        amount1Desired: amountETHToMint,
        amount0Min: 0,
        amount1Min: 0,
        recipient: owner.address,
        deadline: timestamp
      }
      await positionManager.mint(param)
    })
  })

  describe('测试', function () {
    let releaseStarTimestamp: number

    it('设置池地址', async function () {
      const poolAddress = await factory.getPool(igs.target, weth.target, 3000)
      // const poolAddress = '0x92f4Fd0e7BefEf4Ae88a635564bAd9b82C5b20be'
      await defi.setUniswapV3Pool(poolAddress)
      // await contract.setUniswapV3Pool(poolAddress)
    })
    it('设置igs地址', async function () {
      await defi.setIGS(igs.target)
      // await contract.setIGS('0x51f9f9fF6cB2266D68c04eC289c7ABa81378a383')
    })
    it('绑定', async function () {
      await defi.bind('0xb728c15C35ADF40A8627a6dfA2614D8E84f03361')
      const accountInfo = await defi._accountMap(owner)
    })

    it('是否绑定', async () => {
      expect(await defi.isBind(owner)).to.be.true
    })

    it('是否股东', async () => {
      expect(await defi.isShareholder(owner)).to.be.true
    })
    it('奖励10000 igs 质押 70% 1分钟后开始释放, 释放2次, 每次间隔2分钟', async () => {
      const awardIgsAmount = ethers.parseUnits('10000', await igs.decimals())
      releaseStarTimestamp = (await time.latest()) + 60
      await igs.approve(defi.target, awardIgsAmount)
      await defi['gameDividend(address,uint256,uint256,uint256,uint256,uint256)'](
        igs.target,
        awardIgsAmount,
        7000,
        releaseStarTimestamp,
        120,
        2
      )
    })

    it('查看奖励', async () => {
      const records = await defi.dividendsRecord(owner)
      for (let i = 0; i < records.length; i++) {
        const record = records[i]
        console.log(
          `token: ${record.token}; symbol: ${record.symbol}; decimals: ${record.decimals}; dividends: ${record.dividends}; dividendsWithdraw: ${record.dividendsWithdraw}; awards: ${record.awards}; releasable: ${record.releasable}; pledge: ${record.pledge}`
        )
      }
    })
    it('释放', async () => {
      let now = await time.latest()
      let timeout = now - releaseStarTimestamp
      if (timeout < 0) {
        console.log(`sleep ${-timeout}s`)
        await time.increase(-timeout)
      }

      let records = await defi.dividendsRecord(owner)
      for (let i = 0; i < records.length; i++) {
        const record = records[i]
        console.log(
          `token: ${record.token}; symbol: ${record.symbol}; decimals: ${record.decimals}; dividends: ${record.dividends}; dividendsWithdraw: ${record.dividendsWithdraw}; awards: ${record.awards}; releasable: ${record.releasable}; pledge: ${record.pledge}`
        )
      }

      console.log('释放')
      await defi.releaseToken(igs.target)

      records = await defi.dividendsRecord(owner)
      for (let i = 0; i < records.length; i++) {
        const record = records[i]
        console.log(
          `token: ${record.token}; symbol: ${record.symbol}; decimals: ${record.decimals}; dividends: ${record.dividends}; dividendsWithdraw: ${record.dividendsWithdraw}; awards: ${record.awards}; releasable: ${record.releasable}; pledge: ${record.pledge}`
        )
      }

      console.log('释放记录')
      const releasedRecords = await defi.releasedRecords(owner)
      for (let i = 0; i < releasedRecords.length; i++) {
        const record = releasedRecords[i]
        console.log(`token: ${record.token}; amount: ${record.amount}; timestamp: ${record.timestamp};`)
      }

      console.log('增加2分钟')
      now = await time.latest()
      timeout = now - (releaseStarTimestamp + 120)
      if (timeout < 0) {
        console.log(`sleep ${-timeout}s`)
        await time.increase(-timeout)
      }

      records = await defi.dividendsRecord(owner)
      for (let i = 0; i < records.length; i++) {
        const record = records[i]
        console.log(
          `token: ${record.token}; symbol: ${record.symbol}; decimals: ${record.decimals}; dividends: ${record.dividends}; dividendsWithdraw: ${record.dividendsWithdraw}; awards: ${record.awards}; releasable: ${record.releasable}; pledge: ${record.pledge}`
        )
      }
    })

    it('提现', async () => {
      const balance = await igs.balanceOf(owner)
      await defi.withdraw(igs.target, ethers.parseUnits('6500', await igs.decimals()))
      const newBalance = await igs.balanceOf(owner)
      console.log(`balance ${balance}; newBalance: ${newBalance}; xxx: ${newBalance - balance}`)
    })
  })
})

function formatRPCTime(timestamp: number) {
  const date = new Date(timestamp * 1000)
  const Year = date.getFullYear()
  const Moth = date.getMonth() + 1 < 10 ? '0' + (date.getMonth() + 1) : date.getMonth() + 1
  const Day = date.getDate() < 10 ? '0' + date.getDate() : date.getDate()
  const Hour = date.getHours() < 10 ? '0' + date.getHours() : date.getHours()
  const Minute = date.getMinutes() < 10 ? '0' + date.getMinutes() : date.getMinutes()
  const Sechond = date.getSeconds() < 10 ? '0' + date.getSeconds() : date.getSeconds()
  return Year + '-' + Moth + '-' + Day + ' ' + Hour + ':' + Minute + ':' + Sechond
}
