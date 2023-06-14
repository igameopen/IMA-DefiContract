import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { utils } from "ethers"

describe("Defi", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployDefiFixture() {

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const Defi = await ethers.getContractFactory("Defi");
    const contract = await Defi.deploy();

    return { contract, owner, otherAccount };
  }

  describe("测试", function () {
    // it("设置池地址", async function () {
    //     const { contract, owner, otherAccount } = await loadFixture(deployDefiFixture);
    //     const poolAddress = "0xb728c15C35ADF40A8627a6dfA2614D8E84f03361";
    //     await contract.setUniswapV3Pool(poolAddress)
    //     expect(await contract._uniswapV3Pool()).to.equal(poolAddress)
    // });


    it("绑定", async function () {
      const { contract, owner, otherAccount } = await loadFixture(deployDefiFixture);
      await contract.bind("0xb728c15C35ADF40A8627a6dfA2614D8E84f03361")
      const accountInfo = await contract._accountMap(owner.address)
      expect(accountInfo.id).to.equal(1)
    });
  });
});