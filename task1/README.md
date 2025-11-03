# Meme 代币与流动性池操作指南

本项目包含一个具有交易税机制和流动性池功能的 Meme 代币系统。本指南将详细说明如何部署和使用该代币合约。

## 目录

- [项目概述](#项目概述)
- [环境准备](#环境准备)
- [编译合约](#编译合约)
- [部署合约](#部署合约)
- [初始配置](#初始配置)
- [代币交易](#代币交易)
- [流动性管理](#流动性管理)
- [高级功能](#高级功能)
- [常见问题](#常见问题)

---

## 项目概述

### Meme 代币合约 (Meme.sol)

Meme 代币是一个 ERC20 代币，具有以下特性：

- **交易税机制**：买入和卖出时自动收取税费（可配置，最高 10%）
- **交易限制**：单笔交易最大额度限制和每日交易次数限制
- **税务豁免**：可设置特定地址免征税费
- **限制豁免**：可设置特定地址不受交易限制约束
- **暂停功能**：紧急情况下可暂停所有交易
- **代币销毁**：支持代币销毁功能

### 流动性池合约 (LiquidityPool.sol)

流动性池提供以下功能：

- **添加流动性**：使用 Meme 代币和 ETH 添加流动性
- **移除流动性**：移除流动性并取回代币和 ETH
- **代币交易**：
  - 使用 ETH 购买 Meme 代币
  - 使用 Meme 代币购买 ETH
- **恒定乘积做市商 (CPMM)**：使用 x * y = k 公式计算价格

---

## 环境准备

### 1. 安装依赖

```bash
npm install
```

### 2. 配置网络（可选）

如果需要部署到测试网或主网，需要在 `hardhat.config.js` 中配置网络信息：

```javascript
module.exports = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
      url: "https://sepolia.infura.io/v3/YOUR_PROJECT_ID",
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
```

### 3. 准备测试账户

确保你有一个测试账户，并拥有足够的 ETH 用于部署和操作。

---

## 编译合约

在部署之前，需要编译合约：

```bash
npx hardhat compile
```

编译成功后，编译产物将保存在 `artifacts` 目录中。

---

## 部署合约

### 方式一：使用 Hardhat Ignition 部署（推荐）

使用内置的部署脚本进行部署：

```bash
npx hardhat ignition deploy ./ignition/modules/MemeLiquidityPool.js --network localhost
```

#### 部署参数说明

部署脚本支持以下可选参数（如不指定，将使用默认值）：

- `memeName`: 代币名称（默认：`"Meme Token"`）
- `memeSymbol`: 代币符号（默认：`"MEME"`）
- `memeTotalSupply`: 代币总供应量（默认：`1000000000000000000000000000`，即 10 亿代币，18 位小数）
- `buyTaxRate`: 买入税率，以基点为单位（默认：`500`，即 5%）
- `sellTaxRate`: 卖出税率，以基点为单位（默认：`500`，即 5%）
- `taxRecipient`: 税费接收地址（默认：部署者地址）
- `maxTransactionAmount`: 单笔交易最大额度（默认：`10000000000000000000000000`，即 1000 万代币）
- `dailyTransactionLimit`: 每日交易次数限制（默认：`50`）

#### 自定义参数部署示例

```bash
npx hardhat ignition deploy ./ignition/modules/MemeLiquidityPool.js \
  --parameters '{"MemeLiquidityPoolModule":{"memeName":"My Meme","memeSymbol":"MME","buyTaxRate":"300","sellTaxRate":"300"}}' \
  --network localhost
```

### 方式二：启动本地节点后部署

1. 启动本地 Hardhat 节点：

```bash
npx hardhat node
```

2. 在另一个终端中执行部署：

```bash
npx hardhat ignition deploy ./ignition/modules/MemeLiquidityPool.js --network localhost
```

### 部署后的合约地址

部署完成后，合约地址会保存在：
- `ignition/deployments/chain-31337/deployed_addresses.json`

或者可以通过 Hardhat console 查询：

```bash
npx hardhat console --network localhost
```

```javascript
const deployment = require("./ignition/deployments/chain-31337/deployed_addresses.json");
const memeAddress = deployment["MemeLiquidityPoolModule#Meme"];
const poolAddress = deployment["MemeLiquidityPoolModule#LiquidityPool"];
console.log("Meme 代币地址:", memeAddress);
console.log("流动性池地址:", poolAddress);
```

---

## 初始配置

### 1. 取消暂停合约

合约部署后默认处于暂停状态，需要先取消暂停才能进行交易：

```javascript
// 使用 Hardhat console
npx hardhat console --network localhost

const deployment = require("./ignition/deployments/chain-31337/deployed_addresses.json");
const meme = await ethers.getContractAt("Meme", deployment["MemeLiquidityPoolModule#Meme"]);
const pool = await ethers.getContractAt("LiquidityPool", deployment["MemeLiquidityPoolModule#LiquidityPool"]);

// 取消暂停 Meme 代币合约
await meme.unpause();

// 取消暂停流动性池合约
await pool.unpause();

console.log("合约已启用");
```

### 2. 检查合约状态

```javascript
// 检查是否暂停
const memePaused = await meme.paused();
const poolPaused = await pool.paused();
console.log("Meme 代币暂停状态:", memePaused);
console.log("流动性池暂停状态:", poolPaused);

// 查看代币信息
const totalSupply = await meme.totalSupply();
const balance = await meme.balanceOf(await ethers.provider.getSigner().getAddress());
console.log("代币总供应量:", ethers.formatEther(totalSupply));
console.log("部署者余额:", ethers.formatEther(balance));
```

### 3. 首次添加流动性

在开始交易之前，需要先向流动性池添加流动性：

```javascript
const deployment = require("./ignition/deployments/chain-31337/deployed_addresses.json");
const meme = await ethers.getContractAt("Meme", deployment["MemeLiquidityPoolModule#Meme"]);
const pool = await ethers.getContractAt("LiquidityPool", deployment["MemeLiquidityPoolModule#LiquidityPool"]);

const signer = await ethers.provider.getSigner();
const userAddress = await signer.getAddress();

// 准备添加流动性
// 例如：添加 1000 个代币和 1 ETH
const memeAmount = ethers.parseEther("1000");
const ethAmount = ethers.parseEther("1");

// 1. 先批准流动性池可以花费代币
await meme.approve(await pool.getAddress(), memeAmount);
console.log("已批准代币");

// 2. 添加流动性（需要同时发送 ETH）
const tx = await pool.addLiquidity(memeAmount, { value: ethAmount });
await tx.wait();
console.log("流动性已添加");

// 3. 查看池子状态
const poolInfo = await pool.getPoolInfo();
console.log("池子信息:", {
  meme储备量: ethers.formatEther(poolInfo[0]),
  eth储备量: ethers.formatEther(poolInfo[1]),
  总流动性代币: ethers.formatEther(poolInfo[2]),
  交易手续费: poolInfo[3].toString() + " 基点",
  当前价格: ethers.formatEther(poolInfo[4]) + " ETH/MEME"
});

// 4. 查看你的流动性份额
const userLiquidity = await pool.getUserLiquidityInfo(userAddress);
console.log("你的流动性信息:", {
  流动性代币余额: ethers.formatEther(userLiquidity[0]),
  对应Meme代币: ethers.formatEther(userLiquidity[1]),
  对应ETH: ethers.formatEther(userLiquidity[2]),
  份额占比: (Number(userLiquidity[3]) / 100).toFixed(2) + "%"
});
```

---

## 代币交易

### 使用 ETH 购买 Meme 代币（买入）

```javascript
const deployment = require("./ignition/deployments/chain-31337/deployed_addresses.json");
const pool = await ethers.getContractAt("LiquidityPool", deployment["MemeLiquidityPoolModule#LiquidityPool"]);
const meme = await ethers.getContractAt("Meme", deployment["MemeLiquidityPoolModule#Meme"]);

const signer = await ethers.provider.getSigner();
const userAddress = await signer.getAddress();

// 1. 先查看当前价格，计算预期得到的代币数量
const ethAmount = ethers.parseEther("0.1"); // 使用 0.1 ETH 购买
const [expectedMemeOut, priceImpact] = await pool.getAmountOut(ethers.ZeroAddress, ethAmount);
console.log("预计得到代币:", ethers.formatEther(expectedMemeOut));
console.log("价格影响:", (Number(priceImpact) / 100).toFixed(2) + "%");

// 2. 执行买入交易（设置滑点保护，最少获得 95% 的预期数量）
const minMemeOut = expectedMemeOut * BigInt(95) / BigInt(100);
const tx = await pool.swapEthForMeme(minMemeOut, { value: ethAmount });
await tx.wait();
console.log("买入成功");

// 3. 查看余额变化
const balance = await meme.balanceOf(userAddress);
console.log("当前代币余额:", ethers.formatEther(balance));
```

### 使用 Meme 代币购买 ETH（卖出）

```javascript
const deployment = require("./ignition/deployments/chain-31337/deployed_addresses.json");
const pool = await ethers.getContractAt("LiquidityPool", deployment["MemeLiquidityPoolModule#LiquidityPool"]);
const meme = await ethers.getContractAt("Meme", deployment["MemeLiquidityPoolModule#Meme"]);

const signer = await ethers.provider.getSigner();
const userAddress = await signer.getAddress();

// 1. 先查看当前价格，计算预期得到的 ETH 数量
const memeAmount = ethers.parseEther("100"); // 卖出 100 个代币
const [expectedEthOut, priceImpact] = await pool.getAmountOut(await meme.getAddress(), memeAmount);
console.log("预计得到ETH:", ethers.formatEther(expectedEthOut));
console.log("价格影响:", (Number(priceImpact) / 100).toFixed(2) + "%");

// 2. 批准流动性池可以花费代币
await meme.approve(await pool.getAddress(), memeAmount);
console.log("已批准代币");

// 3. 执行卖出交易（设置滑点保护，最少获得 95% 的预期数量）
const minEthOut = expectedEthOut * BigInt(95) / BigInt(100);
const tx = await pool.swapMemeForEth(memeAmount, minEthOut);
await tx.wait();
console.log("卖出成功");

// 4. 查看余额变化
const balance = await meme.balanceOf(userAddress);
const ethBalance = await ethers.provider.getBalance(userAddress);
console.log("当前代币余额:", ethers.formatEther(balance));
console.log("当前ETH余额:", ethers.formatEther(ethBalance));
```

### 查看交易税费

在交易过程中，系统会自动计算并收取税费。可以通过以下方式查看税费：

```javascript
const deployment = require("./ignition/deployments/chain-31337/deployed_addresses.json");
const meme = await ethers.getContractAt("Meme", deployment["MemeLiquidityPoolModule#Meme"]);
const pool = await ethers.getContractAt("LiquidityPool", deployment["MemeLiquidityPoolModule#LiquidityPool"]);

const poolAddress = await pool.getAddress();
const memeAmount = ethers.parseEther("100");

// 计算买入税费（从流动性池买入）
const buyTax = await meme.calculateTax(poolAddress, await ethers.provider.getSigner().getAddress(), memeAmount);
console.log("买入税费:", ethers.formatEther(buyTax));

// 计算卖出税费（向流动性池卖出）
const sellTax = await meme.calculateTax(await ethers.provider.getSigner().getAddress(), poolAddress, memeAmount);
console.log("卖出税费:", ethers.formatEther(sellTax));

// 查看当前税率
const buyTaxRate = await meme.buyTaxRate();
const sellTaxRate = await meme.sellTaxRate();
console.log("买入税率:", Number(buyTaxRate) / 100 + "%");
console.log("卖出税率:", Number(sellTaxRate) / 100 + "%");
```

### 普通转账（不涉及流动性池）

普通用户之间的转账不会收取税费：

```javascript
const deployment = require("./ignition/deployments/chain-31337/deployed_addresses.json");
const meme = await ethers.getContractAt("Meme", deployment["MemeLiquidityPoolModule#Meme"]);

const signer = await ethers.provider.getSigner();
const recipientAddress = "0x..."; // 替换为接收者地址

const amount = ethers.parseEther("50");
const tx = await meme.transfer(recipientAddress, amount);
await tx.wait();
console.log("转账成功");
```

---

## 流动性管理

### 添加流动性

向流动性池添加更多流动性以获得流动性奖励：

```javascript
const deployment = require("./ignition/deployments/chain-31337/deployed_addresses.json");
const meme = await ethers.getContractAt("Meme", deployment["MemeLiquidityPoolModule#Meme"]);
const pool = await ethers.getContractAt("LiquidityPool", deployment["MemeLiquidityPoolModule#LiquidityPool"]);

const signer = await ethers.provider.getSigner();
const userAddress = await signer.getAddress();

// 1. 准备添加的流动性数量
const memeAmount = ethers.parseEther("500");
const ethAmount = ethers.parseEther("0.5");

// 2. 计算将得到的流动性代币数量
const expectedLPTokens = await pool.calculateLiquidityTokens(memeAmount, ethAmount);
console.log("预计得到流动性代币:", ethers.formatEther(expectedLPTokens));

// 3. 批准代币
await meme.approve(await pool.getAddress(), memeAmount);
console.log("已批准代币");

// 4. 添加流动性（需要同时发送 ETH）
const tx = await pool.addLiquidity(memeAmount, { value: ethAmount });
const receipt = await tx.wait();
console.log("流动性已添加");

// 5. 查看更新后的流动性信息
const userLiquidity = await pool.getUserLiquidityInfo(userAddress);
console.log("你的流动性信息:", {
  流动性代币余额: ethers.formatEther(userLiquidity[0]),
  对应Meme代币: ethers.formatEther(userLiquidity[1]),
  对应ETH: ethers.formatEther(userLiquidity[2]),
  份额占比: (Number(userLiquidity[3]) / 100).toFixed(2) + "%"
});
```

**注意**：添加流动性时，代币和 ETH 的比例应该与当前池子中的比例保持一致，否则多余的部分会被退还。

### 移除流动性

从流动性池中移除流动性：

```javascript
const deployment = require("./ignition/deployments/chain-31337/deployed_addresses.json");
const pool = await ethers.getContractAt("LiquidityPool", deployment["MemeLiquidityPoolModule#LiquidityPool"]);

const signer = await ethers.provider.getSigner();
const userAddress = await signer.getAddress();

// 1. 查看当前流动性信息
const userLiquidity = await pool.getUserLiquidityInfo(userAddress);
console.log("当前流动性代币:", ethers.formatEther(userLiquidity[0]));

// 2. 计算移除部分流动性后将得到的代币数量
const removeAmount = userLiquidity[0] / BigInt(2); // 移除一半
const [expectedMeme, expectedEth] = await pool.calculateRemoveLiquidity(removeAmount);
console.log("预计得到Meme代币:", ethers.formatEther(expectedMeme));
console.log("预计得到ETH:", ethers.formatEther(expectedEth));

// 3. 移除流动性
const tx = await pool.removeLiquidity(removeAmount);
await tx.wait();
console.log("流动性已移除");

// 4. 查看更新后的余额
const meme = await ethers.getContractAt("Meme", deployment["MemeLiquidityPoolModule#Meme"]);
const memeBalance = await meme.balanceOf(userAddress);
const ethBalance = await ethers.provider.getBalance(userAddress);
console.log("当前Meme代币余额:", ethers.formatEther(memeBalance));
console.log("当前ETH余额:", ethers.formatEther(ethBalance));
```

### 查看池子状态

```javascript
const deployment = require("./ignition/deployments/chain-31337/deployed_addresses.json");
const pool = await ethers.getContractAt("LiquidityPool", deployment["MemeLiquidityPoolModule#LiquidityPool"]);

const poolInfo = await pool.getPoolInfo();
console.log("池子完整信息:", {
  Meme代币储备量: ethers.formatEther(poolInfo[0]),
  ETH储备量: ethers.formatEther(poolInfo[1]),
  总流动性代币: ethers.formatEther(poolInfo[2]),
  交易手续费: poolInfo[3].toString() + " 基点 (" + (Number(poolInfo[3]) / 100).toFixed(2) + "%)",
  当前价格: ethers.formatEther(poolInfo[4]) + " ETH/MEME",
  是否暂停: poolInfo[5]
});
```

---

## 高级功能

### 代币销毁

任何持有代币的地址都可以销毁自己的代币：

```javascript
const deployment = require("./ignition/deployments/chain-31337/deployed_addresses.json");
const meme = await ethers.getContractAt("Meme", deployment["MemeLiquidityPoolModule#Meme"]);

const burnAmount = ethers.parseEther("100");
const tx = await meme.burn(burnAmount);
await tx.wait();
console.log("代币已销毁");

const totalSupply = await meme.totalSupply();
console.log("当前总供应量:", ethers.formatEther(totalSupply));
```

### 管理员功能

以下功能只能由合约所有者（部署者）调用：

#### 1. 设置税率

```javascript
const deployment = require("./ignition/deployments/chain-31337/deployed_addresses.json");
const meme = await ethers.getContractAt("Meme", deployment["MemeLiquidityPoolModule#Meme"]);

// 设置买入税率为 3%（300 基点）
await meme.setBuyTaxRate(300);
console.log("买入税率已更新为 3%");

// 设置卖出税率为 3%（300 基点）
await meme.setSellTaxRate(300);
console.log("卖出税率已更新为 3%");
```

#### 2. 设置交易限制

```javascript
// 设置单笔最大交易额度为 500 万代币
const newMaxAmount = ethers.parseEther("5000000");
// 设置每日交易次数限制为 100 次
const newDailyLimit = 100;

await meme.setTransactionLimits(newMaxAmount, newDailyLimit);
console.log("交易限制已更新");
```

#### 3. 设置税务豁免

```javascript
const exemptAddress = "0x..."; // 要豁免的地址
await meme.setTaxExemption(exemptAddress, true);
console.log("地址已设置为税务豁免");

// 批量设置
const addresses = ["0x...", "0x...", "0x..."];
await meme.batchSetTaxExemption(addresses, true);
console.log("批量设置完成");
```

#### 4. 设置限制豁免

```javascript
const exemptAddress = "0x..."; // 要豁免的地址
await meme.setLimitExemption(exemptAddress, true);
console.log("地址已设置为限制豁免");
```

#### 5. 暂停/恢复交易

```javascript
// 暂停所有交易
await meme.pause();
console.log("合约已暂停");

// 恢复交易
await meme.unpause();
console.log("合约已恢复");
```

#### 6. 设置交易手续费（流动性池）

```javascript
const deployment = require("./ignition/deployments/chain-31337/deployed_addresses.json");
const pool = await ethers.getContractAt("LiquidityPool", deployment["MemeLiquidityPoolModule#LiquidityPool"]);

// 设置交易手续费为 0.5%（50 基点）
await pool.setTradingFee(50);
console.log("交易手续费已更新");
```

### 查询功能

#### 查看每日交易次数

```javascript
const deployment = require("./ignition/deployments/chain-31337/deployed_addresses.json");
const meme = await ethers.getContractAt("Meme", deployment["MemeLiquidityPoolModule#Meme"]);

const userAddress = "0x..."; // 要查询的地址
const todayCount = await meme.getTodayTransactionCount(userAddress);
console.log("今日交易次数:", todayCount.toString());
```

#### 查看是否豁免税费/限制

```javascript
const userAddress = "0x...";
const exemptFromTax = await meme.exemptFromTax(userAddress);
const exemptFromLimits = await meme.exemptFromLimits(userAddress);
console.log("是否税务豁免:", exemptFromTax);
console.log("是否限制豁免:", exemptFromLimits);
```

---

## 常见问题

### 1. 为什么交易失败？

可能的原因：
- 合约处于暂停状态：需要先调用 `unpause()` 
- 交易金额超过单笔最大额度：检查 `maxTransactionAmount`
- 超过每日交易次数限制：检查 `dailyTransactionLimit`
- 余额不足：确保有足够的代币或 ETH
- 没有授权：使用 `approve()` 授权流动性池花费代币
- 滑点过大：调整 `minMemeOut` 或 `minEthOut` 参数

### 2. 如何计算交易税费？

税费计算公式：
- 买入税费 = 交易金额 × 买入税率 / 10000
- 卖出税费 = 交易金额 × 卖出税率 / 10000

例如：买入税率 500 基点（5%），交易 1000 代币，税费 = 1000 × 500 / 10000 = 50 代币

### 3. 添加流动性时的比例问题

添加流动性时，代币和 ETH 的比例应该尽量接近当前池子中的比例。如果比例不匹配，多余的部分会被自动退还。

### 4. 如何查看交易历史？

可以在 Etherscan 或其他区块链浏览器上查看合约的交易历史，或者监听合约事件。

### 5. 合约是否安全？

- 使用了 OpenZeppelin 的安全合约库
- 实现了重入攻击防护（ReentrancyGuard）
- 支持暂停功能以便紧急情况处理
- 交易限制和税费机制经过精心设计

但建议在生产环境部署前进行充分的安全审计。

---

## 测试

### 运行所有测试

运行完整的测试套件（包括 Meme.sol 和 LiquidityPool.sol 的所有测试）：

```bash
npx hardhat test
```

### 运行特定测试文件

只运行 Meme 代币合约的测试：

```bash
npx hardhat test test/Meme.test.js
```

只运行流动性池合约的测试：

```bash
npx hardhat test test/LiquidityPool.test.js
```

### 运行特定测试用例

使用 `--grep` 选项运行包含特定关键词的测试：

```bash
# 只运行包含"部署"的测试
npx hardhat test --grep "部署"

# 只运行包含"税费"的测试
npx hardhat test --grep "税费机制"

# 只运行包含"流动性"的测试
npx hardhat test --grep "流动性"
```

### 生成 Gas 使用报告

运行测试并生成详细的 Gas 使用报告：

```bash
REPORT_GAS=true npx hardhat test
```

### 其他有用的测试选项

```bash
# 详细输出模式
npx hardhat test --verbose

# 并行运行测试（默认开启）
npx hardhat test --parallel

# 不并行运行（依次执行测试）
npx hardhat test --no-compile

# 重新编译合约并运行测试
npx hardhat clean && npx hardhat compile && npx hardhat test

# 运行测试并显示覆盖率（需要 solidity-coverage 插件）
npx hardhat coverage
```

### 查看测试覆盖率

运行覆盖率测试后，会生成详细的覆盖率报告：

```bash
npx hardhat coverage
```

#### 覆盖率报告说明

覆盖率测试会在终端显示一个表格，显示以下指标：

- **% Stmts（语句覆盖率）**：已执行的语句百分比
- **% Branch（分支覆盖率）**：已执行的分支（if/else 等）百分比
- **% Funcs（函数覆盖率）**：已调用的函数百分比
- **% Lines（行覆盖率）**：已执行的行数百分比

#### 当前测试覆盖率

根据最新测试结果：

| 合约 | 语句覆盖率 | 分支覆盖率 | 函数覆盖率 | 行覆盖率 |
|------|-----------|-----------|-----------|---------|
| **LiquidityPool.sol** | 94.12% | 61.11% | 100% | 96.95% |
| **Meme.sol** | 100% | 69.15% | 100% | 100% |
| **总体** | 96.82% | 65.22% | 100% | 98.29% |

> **注意**：分支覆盖率（Branch Coverage）通常难以达到100%，因为它需要测试所有可能的条件组合。当前65.22%的分支覆盖率已经覆盖了主要的业务逻辑路径。达到100%的分支覆盖率需要测试大量的边界条件和错误处理路径，在实际项目中通常不必要。

#### 查看详细的 HTML 覆盖率报告

覆盖率测试会在 `coverage/` 目录下生成 HTML 报告：

```bash
# 在浏览器中打开覆盖率报告
open coverage/index.html

# 或者在 Windows 上
start coverage/index.html

# 或者在 Linux 上
xdg-open coverage/index.html
```

HTML 报告会显示：
- 每个文件的详细覆盖率
- 未覆盖的代码行（红色高亮）
- 部分覆盖的代码行（黄色高亮）
- 已覆盖的代码行（绿色高亮）

#### 覆盖率报告文件

覆盖率测试会生成以下文件：

- `coverage/index.html` - 主报告页面（推荐使用）
- `coverage/coverage-final.json` - JSON 格式的覆盖率数据
- `coverage/lcov.info` - LCOV 格式的覆盖率数据（可用于 CI/CD）
- `coverage/contracts/` - 各个合约文件的详细 HTML 报告

#### 提高覆盖率的建议

如果某些代码未被测试覆盖：
1. 查看 HTML 报告找出未覆盖的行
2. 添加相应的测试用例
3. 特别关注：
   - 错误处理路径（require/revert）
   - 边界条件
   - 管理员功能的权限检查
   - 各种 if/else 分支

### 测试文件说明

- **test/Meme.test.js**: Meme 代币合约的测试，包含 26 个测试用例，覆盖：
  - 部署和初始化
  - 税费机制（买入税、卖出税）
  - 交易限制（单笔额度限制、每日次数限制）
  - 暂停功能
  - 代币销毁
  - 管理员功能
  - 查询功能

- **test/LiquidityPool.test.js**: 流动性池合约的测试，包含 25 个测试用例，覆盖：
  - 部署和初始化
  - 添加/移除流动性
  - 代币交换（ETH ↔ Meme）
  - 计算函数
  - 管理员功能
  - 最小流动性机制

---

## 技术支持

如有问题，请查看：
- 合约源码：`contracts/Meme.sol` 和 `contracts/LiquidityPool.sol`
- Hardhat 文档：https://hardhat.org/docs
- OpenZeppelin 文档：https://docs.openzeppelin.com/

---

## 许可证

MIT License
