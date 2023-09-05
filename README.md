# iGames Project

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

## 管理员接口

### 设置 IGS token 地址

```
setIGS(address token)
```

---

### 设置 UniswapV3 池子地址

```
setUniswapV3Pool(address uniswapV3Pool)
```

---

### 设置最大股东数

```
setMaxShareholderCount(uint256 count)
```

默认 100

---

### 设置提现上级收益比例

```
setShareFee(uint16 fee)
```

下级提现, 上级获得 下级提现金额的 20%(默认);  
默认 2000 (20%), 如设置 5%, 就输入 500, 以此类推

---

### 分发股东分红

```
gameDividend(address token, uint256 amount)
```

操作员必须先 Approve 相应的数量到合约  
直接根据当前股东列表分发 token

---

### 分发股东分红 (质押)

```
gameDividend(address token, uint256 amount, uint256 percentagePledged, uint256 start, uint256 duration, uint256 releaseCount)
```

token: 分发的 Token 地址  
amount: 分发数量(操作员必须先 Approve 相应的数量到合约)  
percentagePledged: 质押百分比(如质押 20%则输入 2000, 5%输入 500, 以此类推; 分发数量减去这质押的数量, 剩余的就是立刻分发的, 例如这里质押 30%(输入 3000), 则 70%的 token 会立刻分发, 30%则进行质押)  
start: 开始(第一次)释放时间戳(10 位秒数时间戳)  
duration: 释放间隔(到释放时间后, 下一次的释放间隔, 秒为单位, 如 01:00 开始释放, 下一次一分钟释放后则输入 60)  
releaseCount: 释放次数

例如 分发 1000 IGS, 质押 700 IGS, 2023 年 10 月 1 日 0 时 0 分 0 秒开始释放, 分 3 次释放, 每次间隔 10 天, 则输入如下

token: 0x51f9f9fF6cB2266D68c04eC289c7ABa81378a383  
amount: 1000000000000000000000  
percentagePledged: 7000  
start: 1696089600 (2023 年 10 月 1 日 0 时 0 分 0 秒时间戳)  
duration: 864000 (10 天的秒数)  
releaseCount: 3

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

### 获取用户 LP

```

getLiquidityGross(address account) public view returns(uint160)

```

---

### 全网股东数

```

shareholderCount() public view returns(uint256)

```

---

### 股东列表

```

shareholders()

```

返回值

```

struct ShareholderRes[] {
address account; // 地址
uint256 createdTime; // 加入时间
uint160 liquidity; // 流动性
}

```

---

### 池子 SqrtPriceX96 (上次跟你说的那个计算方式算出 eth 兑 igs 值)

```

poolSqrtPriceX96() external view returns(uint160)

```

---

### 分红统计\[待提现, 已提现, 分润, 已释放, 质押\](二维数组)

```

dividendsRecord(address account) external view returns(TokenAmountRes[] memory)

```

返回例子 [[0x6d79C1ce49f6F3fc04CEF35c165484E027acc37E,IGS,18,1000, 1000, 1000]]

```

struct TokenAmountRes {
address token; // token
string symbol; // 简称
uint8 decimals; // 小数位
uint256 dividends; // 待提现
uint256 dividendsWithdraw; // 已提现
uint256 awards; // 分润
uint256 releasable; // 已释放
uint256 pledge; // 质押
}

```

---

### 分红记录

```
dividendRecords(address account)
```

返回

```
struct DividendRecord {
    address token;
    uint256 amount;
    uint256 timestamp;
}
```

---

### 释放记录

```

releasedRecords(address beneficiary)

```

返回值

```

struct ReleasedRecord {
address token; // token 地址
uint256 timestamp; // 释放时间
uint256 amount; // 释放数量
}

```

---

### 推荐人数

```

recommendCount(address account) external view returns(uint256)

```

---

### 推荐总 LP

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

### 提现

```

withdraw(address token, uint256 amount)

```

参数
token: 提现的
token 地址
amount: 金额

---

### 释放金额

```

releaseToken(address token)

```

---

```

```
