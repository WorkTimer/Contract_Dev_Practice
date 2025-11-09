# Foundry 智能合约开发工具链

**Foundry** 是一个用 Rust 编写的快速、可移植和模块化的以太坊应用开发工具包，为智能合约的测试、部署和调试提供了完整的工具链支持。

## Foundry 工具链组成

Foundry 由四个核心工具组成，覆盖了智能合约开发的完整生命周期：

### 1. Forge - 测试与构建框架

**功能：**
- 🔨 **编译合约**：快速编译 Solidity 智能合约
- 🧪 **单元测试**：支持 Solidity 和 Rust 编写的测试
- 📊 **Gas 分析**：生成详细的 Gas 消耗报告
- 🔍 **代码覆盖率**：分析测试覆盖率
- 📦 **依赖管理**：通过 Git submodules 管理依赖

**主要命令：**
```bash
# 编译合约
forge build

# 运行测试
forge test

# 生成 Gas 报告
forge test --gas-report

# 代码格式化
forge fmt

# 生成 Gas 快照
forge snapshot
```

### 2. Cast - 链上交互工具

**功能：**
- 📡 **发送交易**：与智能合约交互，调用函数
- 📊 **查询链数据**：获取区块、交易、账户信息
- 🔢 **数据转换**：处理 ABI 编码/解码、地址格式转换
- 💰 **余额查询**：查询账户 ETH 和代币余额
- 🔐 **签名验证**：验证消息签名

**主要命令：**
```bash
# 调用合约函数
cast send <CONTRACT> "functionName()" --rpc-url <RPC_URL> --private-key <KEY>

# 查询合约状态
cast call <CONTRACT> "functionName()" --rpc-url <RPC_URL>

# 获取账户余额
cast balance <ADDRESS> --rpc-url <RPC_URL>

# ABI 编码
cast abi-encode "functionName(uint256)" 123
```

### 3. Anvil - 本地开发节点

**功能：**
- 🏠 **本地节点**：运行本地以太坊节点，类似 Ganache
- ⚡ **快速测试**：无需等待区块确认，即时执行交易
- 🔧 **分叉主网**：可以分叉以太坊主网或测试网进行测试
- 🎯 **账户管理**：自动创建测试账户和私钥
- ⏱️ **时间控制**：可以手动推进区块时间

**主要命令：**
```bash
# 启动本地节点
anvil

# 分叉主网
anvil --fork-url <RPC_URL>

# 指定端口和账户数量
anvil --port 8545 --accounts 10
```

### 4. Chisel - Solidity REPL

**功能：**
- 💻 **交互式环境**：实时编写和测试 Solidity 代码片段
- 🚀 **快速原型**：快速验证代码逻辑
- 📝 **语法检查**：即时检查 Solidity 语法错误
- 🔍 **调试工具**：快速测试函数和表达式

**主要命令：**
```bash
# 启动 Chisel
chisel

# 在 REPL 中直接编写 Solidity 代码
> uint256 x = 100;
> x + 50;
```

## 项目简介

本项目是一个智能合约 Gas 优化实践项目，演示了如何使用 Foundry 进行智能合约开发、测试和 Gas 优化分析。

### 项目内容

本项目包含三个版本的算术运算智能合约，用于对比不同的 Gas 优化策略：

1. **Arithmetic.sol** - 原始未优化版本
2. **ArithmeticOptimized1.sol** - 优化版本1（使用 unchecked 块和减少存储操作）
3. **ArithmeticOptimized2.sol** - 优化版本2（使用自定义错误和变量打包）

### 合约功能

所有合约实现了基本的四则运算：
- `add(uint256 a, uint256 b)` - 加法
- `subtract(uint256 a, uint256 b)` - 减法
- `multiply(uint256 a, uint256 b)` - 乘法
- `divide(uint256 a, uint256 b)` - 除法
- `reset()` - 重置状态

### Gas 优化策略与成果

#### 优化版本1 (ArithmeticOptimized1)
**优化策略：**
- 使用 `unchecked` 块避免不必要的溢出检查
- 减少存储变量的写入次数
- 移除不必要的字符串存储

**优化成果：**
- 部署成本：节省 64.5% (272,037 vs 765,640 Gas)
- 运行时 Gas：平均节省 25-30%
  - 加法：节省 25.9%
  - 减法：节省 25.7%
  - 乘法：节省 22.3%
  - 除法：节省 28.7%

#### 优化版本2 (ArithmeticOptimized2)
**优化策略：**
- 使用自定义错误替代 `require` 字符串
- 变量打包：将 `uint128` 变量打包到单个存储槽
- 使用 `unchecked` 块减少溢出检查开销
- 移除不必要的字符串存储

**优化成果：**
- 部署成本：节省 11.9% (674,598 vs 765,640 Gas)
- 运行时 Gas：平均节省 40-50%
  - 加法：节省 49.6%
  - 减法：节省 49.3%
  - 乘法：节省 38.5%
  - 除法：节省 43.3%

> 📊 **详细 Gas 优化分析、测试数据和优化技术详解请查看 [GAS_OPTIMIZATION_REPORT.md](./GAS_OPTIMIZATION_REPORT.md)**

## 快速开始

### 安装 Foundry

```bash
# 使用 foundryup 安装（推荐）
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 编译项目

```bash
forge build
```

### 运行测试

```bash
# 运行所有测试
forge test

# 运行测试并显示详细日志
forge test -vv

# 运行测试并生成 Gas 报告
forge test --gas-report
```

### 启动本地节点

```bash
# 启动 Anvil 本地节点
anvil
```

### 部署合约

```bash
# 使用 Forge Script 部署（本地测试，自动使用 Anvil 默认账户）
forge script script/DeployArithmetic.s.sol:DeployArithmetic \
  --rpc-url http://localhost:8545

# 实际部署到测试网（需要设置 PRIVATE_KEY 环境变量）
forge script script/DeployArithmetic.s.sol:DeployArithmetic \
  --rpc-url <RPC_URL> \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## 项目结构

```
task3/
├── src/                          # 合约源代码
│   ├── Arithmetic.sol            # 原始未优化版本
│   ├── ArithmeticOptimized1.sol  # 优化版本1
│   └── ArithmeticOptimized2.sol # 优化版本2
├── test/                         # 测试文件
│   └── ArithmeticGasTest.t.sol   # Gas 对比测试
├── script/                       # 部署脚本
│   └── DeployArithmetic.s.sol    # 部署脚本
├── lib/                          # 依赖库
├── foundry.toml                  # Foundry 配置文件
├── README.md                     # 本文件
└── GAS_OPTIMIZATION_REPORT.md    # 详细 Gas 优化报告
```

## Foundry 工作流程

### 1. 开发阶段

```bash
# 1. 编写合约代码
vim src/MyContract.sol

# 2. 格式化代码
forge fmt

# 3. 编译检查
forge build

# 4. 使用 Chisel 快速测试代码片段
chisel
```

### 2. 测试阶段

```bash
# 1. 编写测试
vim test/MyContract.t.sol

# 2. 运行测试
forge test

# 3. 查看 Gas 消耗
forge test --gas-report

# 4. 检查代码覆盖率
forge coverage
```

### 3. 调试阶段

```bash
# 1. 启动本地节点
anvil

# 2. 使用 Cast 与合约交互
cast send <CONTRACT> "function()" --rpc-url http://localhost:8545

# 3. 使用 Forge 进行调试
forge test --debug <TEST_FUNCTION>
```

### 4. 部署阶段

```bash
# 1. 启动 Anvil 本地节点
anvil

# 2. 模拟部署（不实际发送交易，自动使用 Anvil 默认账户）
forge script script/DeployArithmetic.s.sol:DeployArithmetic \
  --rpc-url http://localhost:8545

# 3. 实际部署到测试网
forge script script/DeployArithmetic.s.sol:DeployArithmetic \
  --rpc-url <RPC_URL> \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## 核心优势

### 性能优势
- ⚡ **极速编译**：Rust 编写，编译速度远超其他工具
- 🚀 **快速测试**：测试执行速度比 Hardhat 快 10-100 倍
- 💨 **即时反馈**：实时编译和测试反馈

### 开发体验
- 📝 **Solidity 测试**：使用 Solidity 编写测试，无需学习 JavaScript/TypeScript
- 🔧 **强大工具链**：测试、部署、调试一体化
- 📊 **详细报告**：Gas 分析、覆盖率报告等

### 灵活性
- 🔌 **模块化设计**：每个工具可独立使用
- 🌐 **多链支持**：支持以太坊、Polygon、Arbitrum 等
- 🔀 **分叉测试**：可以分叉主网进行测试

## 文档资源

- 📚 **官方文档**：https://book.getfoundry.sh/
- 🐙 **GitHub 仓库**：https://github.com/foundry-rs/foundry

## 部署脚本使用指南

### 脚本文件

- `script/DeployArithmetic.s.sol` - 部署所有三个版本的算术运算合约

### 使用方法

#### 1. 本地测试（使用 Anvil）

脚本会自动使用 Anvil 的默认账户，无需设置私钥：

```bash
# 启动 Anvil
anvil

# 在另一个终端模拟部署（不实际发送交易）
forge script script/DeployArithmetic.s.sol:DeployArithmetic \
  --rpc-url http://localhost:8545

# 实际部署到本地节点
forge script script/DeployArithmetic.s.sol:DeployArithmetic \
  --rpc-url http://localhost:8545 \
  --broadcast
```

#### 2. 部署到测试网

```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key_here

# 模拟部署（不实际发送交易）
forge script script/DeployArithmetic.s.sol:DeployArithmetic \
  --rpc-url <RPC_URL>

# 实际部署并验证
forge script script/DeployArithmetic.s.sol:DeployArithmetic \
  --rpc-url <RPC_URL> \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key <ETHERSCAN_API_KEY>
```

#### 3. 脚本功能

- `run()` - 部署所有三个版本的合约
- `deployOriginal()` - 仅部署原始版本
- `deployOptimized1()` - 仅部署优化版本1
- `deployOptimized2()` - 仅部署优化版本2

#### 4. 示例：部署到 Sepolia 测试网

```bash
export PRIVATE_KEY=your_private_key
export ETHERSCAN_API_KEY=your_etherscan_api_key

forge script script/DeployArithmetic.s.sol:DeployArithmetic \
  --rpc-url https://sepolia.infura.io/v3/YOUR_INFURA_KEY \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

⚠️ **安全提示：**
- 永远不要将私钥提交到版本控制系统
- 使用环境变量或 `.env` 文件管理敏感信息
- 在部署到主网前，务必在测试网上充分测试

## 相关文档

- 📊 [Gas 优化详细报告](./GAS_OPTIMIZATION_REPORT.md) - 完整的 Gas 优化分析和测试数据


