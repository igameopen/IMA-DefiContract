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


==== 1
NFT  
0x201BC68Eb7F60d4F97AE51B5ea9CE2326Fea9BF5  
https://goerli.etherscan.io/address/0x201BC68Eb7F60d4F97AE51B5ea9CE2326Fea9BF5


IGS  
0x6d79C1ce49f6F3fc04CEF35c165484E027acc37E  
https://goerli.etherscan.io/address/0x6d79C1ce49f6F3fc04CEF35c165484E027acc37E 


Defi  
0x4acf712896BFD20eDEFd17b2D15fe361b588A2DA  
https://goerli.etherscan.io/address/0x4acf712896BFD20eDEFd17b2D15fe361b588A2DA  


顶级绑定地址  
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
### 分红记录(待提现, 二维数组) 
```
dividendsRecord(address account) external view returns(TokenAmountRes[] memory)   
```
返回例子 [[0x6d79C1ce49f6F3fc04CEF35c165484E027acc37E,IGS,18,1000]]
``` solidity
struct TokenAmountRes {
    address token; // token
    string symbol; // 简称
    uint8 decimals; // 小数位
    uint256 amount; // 金额
}
```   
---
### 提现分红记录(已提现, 同上)   
```
dividendsWithdrawRecord(address account) external view returns(TokenAmountRes[] memory)
```
---
### 分润记录
```
awardRecord(address account) external view returns(AwardRecord[] memory)
```
``` solidity
struct AwardRecord {
    address account;  // 账号地址
    address token;    // token
    string symbol;    // 简称
    uint8 decimals;   // 小数位
    uint256 amount;   // 金额
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
