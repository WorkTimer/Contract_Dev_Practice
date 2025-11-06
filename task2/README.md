# MetaNode Stake 项目

一个基于 ERC1967 可升级代理模式的质押挖矿智能合约系统，支持 ETH 和 ERC20 代币质押，并获得 MetaNode 代币奖励。

## 📋 项目简介

MetaNode Stake 是一个去中心化的质押挖矿平台，具有以下特性：

- **可升级代理模式**：使用 OpenZeppelin 的 ERC1967 代理模式，支持合约升级而不改变用户交互地址
- **多池质押**：支持 ETH 和多种 ERC20 代币的质押
- **灵活的奖励机制**：基于区块的 MetaNode 代币奖励分配
- **安全控制**：支持暂停存款、提取和领取功能，提供紧急安全机制
- **延迟提取**：支持设置提取锁定区块数，增强系统安全性

## 🏗️ 合约架构

### 核心合约

1. **MetaNodeToken** (`MetaNode.sol`)
   - ERC20 代币合约
   - 初始供应量：10,000,000 MetaNode

2. **MetaNodeStake** (`MetaNodeStake.sol`)
   - 质押挖矿主合约（V1 实现）
   - 使用 UUPS 可升级模式
   - 支持 AccessControl 权限管理

3. **MetaNodeStakeV2** (`MetaNodeStakeV2.sol`)
   - 升级后的质押挖矿合约（V2 实现）

4. **ERC1967Proxy**
   - OpenZeppelin 代理合约
   - **这是用户应该使用的固定地址**

### 部署架构

```
MetaNodeToken (独立合约)
    ↓
MetaNodeStake (实现合约 V1) ← ERC1967Proxy (代理合约) ← 用户交互地址
    ↓
MetaNodeStakeV2 (实现合约 V2) ← 升级后指向这里
```

**重要说明**：用户应该始终使用代理合约地址进行交互，即使合约升级后，代理地址保持不变。

## 🌐 已部署合约地址（Sepolia 测试网）

### 用户交互地址（固定不变）

- **代理合约地址（用户使用）**：`0xEc48ea1C4e410CC30b55d07Da6214D3fb6500413`
  - 这是用户应该使用的地址，即使合约升级也不会改变

### 其他合约地址

- **MetaNodeToken（代币合约）**：`0xFb60D4AFE26E277568E25cb050C47b5cD945C49C`
- **MetaNodeStake（实现合约 V1）**：`0xa987eeA51e21911dC7E9709F669429FC97DfAF6C`
- **MetaNodeStakeV2（实现合约 V2）**：`0x95C82ad34920987a561AA51b2985D964e6cA5CF6`

## 🚀 开始项目

### 前置要求

- Node.js >= 18
- npm 或 yarn
- Hardhat

### 安装依赖

```bash
npm install
```

### 环境配置

创建 `.env` 文件并配置以下环境变量：

```env
# Sepolia 网络配置
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
SEPOLIA_PRIVATE_KEY=your_private_key_here
SEPOLIA_PRIVATE_KEY_2=your_private_key_2_here
SEPOLIA_PRIVATE_KEY_3=your_private_key_3_here
SEPOLIA_PRIVATE_KEY_4=your_private_key_4_here
```

## 📦 部署命令

### 本地网络部署

```bash
npm run deploy:local
```

### Sepolia 测试网部署

```bash
npm run deploy:sepolia
```

部署脚本会：
1. 部署 MetaNodeToken 代币合约
2. 部署 MetaNodeStake 实现合约
3. 部署 ERC1967Proxy 代理合约并初始化
4. 返回所有合约地址

### 部署参数

部署时可以通过参数文件覆盖默认值：

- `startBlock`: 质押开始的区块号（默认：100）
- `endBlock`: 质押结束的区块号（默认：10000）
- `metaNodePerBlock`: 每个区块的 MetaNode 奖励（默认：1 ether）

参数文件位置：`ignition/parameters.sepolia.json` 或 `ignition/parameters.local.json`

## 🔄 升级命令

### 本地网络升级

```bash
npm run upgrade:local
```

### Sepolia 测试网升级

```bash
npm run upgrade:sepolia
```

升级脚本会：
1. 自动读取已部署的代理合约地址
2. 部署新的 MetaNodeStakeV2 实现合约
3. 调用 `upgradeToAndCall` 升级代理合约
4. **代理合约地址保持不变**，用户无需更改交互地址

**注意**：升级需要账户具有 `UPGRADE_ROLE` 权限。

## 🧪 测试命令

### Solidity 单元测试

```bash
npm run test:solidity
```

运行 Foundry 风格的 Solidity 测试（`MetaNodeStake.t.sol`）

### Sepolia 网络集成测试

```bash
npm run test:sepolia
```

运行 Sepolia 测试网的集成测试，包括：
- 合约初始化状态检查
- 管理员角色验证
- 池信息查询
- ETH 池存款测试
- 奖励领取测试
- 暂停功能测试

**注意**：Sepolia 测试需要等待交易确认，测试时间较长（约 20 分钟）。

## 📁 项目结构

```
task2/
├── contracts/              # Solidity 合约源码
│   ├── MetaNode.sol       # MetaNodeToken 代币合约
│   ├── MetaNodeStake.sol  # 质押合约 V1
│   ├── MetaNodeStakeV2.sol # 质押合约 V2
│   └── MetaNodeStake.t.sol # Solidity 测试
├── ignition/              # Hardhat Ignition 部署脚本
│   ├── modules/
│   │   ├── MetaNodeDeploy.ts    # 部署模块
│   │   └── MetaNodeUpgrade.ts   # 升级模块
│   └── deployments/       # 部署记录
│       └── chain-11155111/
│           └── deployed_addresses.json
├── test/                  # TypeScript 测试
│   └── MetaNodeStake.sepolia.ts
├── scripts/               # 工具脚本
├── hardhat.config.ts      # Hardhat 配置
└── package.json           # 项目依赖
```

## 🔑 权限角色

合约使用 OpenZeppelin 的 AccessControl 进行权限管理：

- **DEFAULT_ADMIN_ROLE**：超级管理员，可以管理所有角色
- **ADMIN_ROLE**：管理员，可以执行管理操作（添加池、设置参数等）
- **UPGRADE_ROLE**：升级权限，可以升级合约实现

## 📝 主要功能

### 用户功能

- `depositETH()`: 质押 ETH
- `deposit(uint256 _pid, uint256 _amount)`: 质押 ERC20 代币
- `unstake(uint256 _pid, uint256 _amount)`: 请求解质押
- `withdraw(uint256 _pid)`: 提取已解锁的代币
- `claim(uint256 _pid)`: 领取 MetaNode 奖励
- `pendingMetaNode(uint256 _pid, address _user)`: 查询待领取奖励

### 管理员功能

- `addPool()`: 添加新的质押池
- `setPoolWeight()`: 设置池权重
- `updatePool()`: 更新池信息
- `pauseDeposit()/unpauseDeposit()`: 暂停/恢复存款
- `pauseWithdraw()/unpauseWithdraw()`: 暂停/恢复提取
- `pauseClaim()/unpauseClaim()`: 暂停/恢复领取
- `setStartBlock()/setEndBlock()`: 设置开始/结束区块
- `setMetaNodePerBlock()`: 设置每区块奖励

## 🔒 安全特性

- **重入保护**：使用 ReentrancyGuard
- **暂停机制**：支持紧急暂停功能
- **权限控制**：基于角色的访问控制
- **延迟提取**：可配置的提取锁定区块数
- **最小存款限制**：防止小额攻击

## 📚 技术栈

- **Solidity**: ^0.8.28
- **Hardhat**: ^3.0.6
- **OpenZeppelin Contracts**: ^5.4.0
- **TypeScript**: ~5.8.0
- **Ethers.js**: ^6.15.0

## 📄 许可证

MIT License


