# Transfer Tokens - Solana Anchor 程序

这是一个基于 Anchor 框架开发的 Solana 程序，用于创建 SPL Token、铸造代币、转账代币和销毁代币。

## 功能

- **创建代币** (`create_token`): 创建新的 SPL Token 并初始化元数据账户
- **铸造代币** (`mint_token`): 将代币铸造到指定账户
- **转账代币** (`transfer_tokens`): 在账户之间转移代币
- **销毁代币** (`burn_tokens`): 销毁指定数量的代币

## 前置要求

- [Rust](https://www.rust-lang.org/tools/install) 
- [Solana CLI](https://docs.solana.com/cli/install-solana-cli-tools) 
- [Anchor](https://www.anchor-lang.com/docs/installation) 
- [Node.js](https://nodejs.org/) (v18+)
- [pnpm](https://pnpm.io/installation)

## 安装依赖

```bash
# 安装 Rust 依赖（Anchor 会自动处理）
# 安装 Node.js 依赖
pnpm install
```

## 编译、部署和测试步骤

### 1. 编译程序

编译 Solana 程序：

```bash
anchor build
```

编译成功后，程序文件将生成在 `target/deploy/transfer_tokens.so`，IDL 文件在 `target/idl/transfer_tokens.json`。


### 2. 部署程序

部署到本地网络（localnet）：

```bash
anchor deploy
```

程序将部署到配置的 localnet（默认 `http://0.0.0.0:8899`）。

**程序 ID**: `ABw4Sw54Hka5hkmhrQ3bMn2XUksAHtoTeqdhrNxQeQgF`

### 3. 运行测试

使用 Anchor 测试框架运行测试：

```bash
anchor test
```

**注意**: 如果端口 8899 已被占用，需要先停止其他验证器进程。

## 测试说明

测试套件包含以下测试用例：

1. **Create an SPL Token!**: 创建新的 SPL Token 并初始化元数据
2. **Mint tokens!**: 铸造 100 个代币到发送者账户
3. **Transfer tokens!**: 从发送者转账 50 个代币到接收者
4. **Burn tokens!**: 销毁 25 个代币

## 项目结构

```
task4/
├── programs/
│   └── transfer-tokens/
│       └── src/
│           ├── lib.rs              # 程序入口
│           └── instructions/
│               ├── create.rs        # 创建代币指令
│               ├── mint.rs          # 铸造代币指令
│               ├── transfer.rs      # 转账代币指令
│               └── burn.rs          # 销毁代币指令
├── tests/
│   └── test.ts                     # Anchor 测试
├── Anchor.toml                     # Anchor 配置文件
└── package.json                    # Node.js 依赖配置
```

## 配置说明

- **集群**: localnet（可在 `Anchor.toml` 中修改）
- **钱包**: `~/.config/solana/id.json`
- **程序 ID**: `ABw4Sw54Hka5hkmhrQ3bMn2XUksAHtoTeqdhrNxQeQgF`

## 常见问题

### 编译错误：安全检查失败




