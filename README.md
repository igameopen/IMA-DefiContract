# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

## Gorila
NFT  
0x201BC68Eb7F60d4F97AE51B5ea9CE2326Fea9BF5  
https://goerli.etherscan.io/address/0x201BC68Eb7F60d4F97AE51B5ea9CE2326Fea9BF5


IGS  
0x6d79C1ce49f6F3fc04CEF35c165484E027acc37E  
https://goerli.etherscan.io/address/0x6d79C1ce49f6F3fc04CEF35c165484E027acc37E 


Defi  
0xc03407eaa8Bef26930c6BCD9aB65634fdCe84155  
https://goerli.etherscan.io/address/0xc03407eaa8Bef26930c6BCD9aB65634fdCe84155   

UniswapV3Pool   
0xc02e78f308DcF5C42E54d8D8bCAe443c6F1Af8df   
https://goerli.etherscan.io/address/0xc03407eaa8Bef26930c6BCD9aB65634fdCe84155   

---

## Arbiscan
IGS
0x51f9f9fF6cB2266D68c04eC289c7ABa81378a383   
https://arbiscan.io/address/0x51f9f9fF6cB2266D68c04eC289c7ABa81378a383   

Defi   
0xA4fE5bB7035199668B97E5C1f9a54EC83452f3FF   
https://arbiscan.io/address/0xA4fE5bB7035199668B97E5C1f9a54EC83452f3FF#writeContract

UniswapV3Pool   
0x92f4Fd0e7BefEf4Ae88a635564bAd9b82C5b20be   
https://arbiscan.io/address/0x92f4Fd0e7BefEf4Ae88a635564bAd9b82C5b20be   

顶级绑定地址为营销地址   
0xb728c15C35ADF40A8627a6dfA2614D8E84f03361

部分数据可以通过账户 0x3EA29e77cea2bE4FcAA0012A428996F960447Ec4 参数到返回参数


## 读取接口

### 是否绑定  
```
isBind(address account) public view returns(bool)
```
---
### 是否股东  
```
isShareholder(address account) public view returns(bool)
```
---
### 获取用户LP   
```
getLiquidityGross(address account) public view returns(uint160)
```
---
### 全网股东数   
```
shareholderCount() public view returns(uint256)
```
---
### 池子SqrtPriceX96  (上次跟你说的那个计算方式算出 eth 兑 igs 值)   
```
poolSqrtPriceX96() external view returns(uint160)
```
---
### 分红记录\[待提现, 已提现, 分润\](二维数组) 
```
dividendsRecord(address account) external view returns(TokenAmountRes[] memory)   
```
返回例子 [[0x6d79C1ce49f6F3fc04CEF35c165484E027acc37E,IGS,18,1000]]
``` solidity
struct TokenAmountRes {
    address token; // token
    string symbol; // 简称
    uint8 decimals; // 小数位
    uint256 dividends; // 待提现
    uint256 dividendsWithdraw; // 已提现
    uint256 awards; // 分润
}
```    
---
### 推荐人数  
``` 
recommendCount(address account) external view returns(uint256)   
```
---
### 推荐总LP
```
recommendLiquidityGross(address account) external view returns(uint128)
```
---
### 推荐列表
```
function recommends(address account) external view returns(RecommendRes[] memory)
```
```
struct RecommendRes {
    address recommend; // 地址
    uint160 liquidity; // 流动性
}
```
---
## 操作接口 (必须绑定当前钱包操作)

### 绑定推荐人  
```
bind(address referrer)
```
---
### 铸造NFT   
```
mint() external
```
---
### 提现  
``` 
withdraw(address token, uint256 amount)   
```
参数   
token: 提现的token地址   
amount: 金额   

---
