import { expect } from "chai";
import hre from "hardhat";
import { ethers } from "ethers";
import { readFileSync } from "fs";
import { join } from "path";
import { MetaNodeStake, MetaNodeToken} from "../types/ethers-contracts/index.js";


// Sepolia chain ID
const SEPOLIA_CHAIN_ID = 11155111;
const DELAY_MS = 4 * 60 * 1000; // 4 分钟延时

// 延时函数
function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// 读取部署地址
function getDeployedAddresses(): {
  metaNodeToken?: string;
  metaNodeStake?: string;
  proxy?: string;
  proxyStake?: string;
} {
  const deploymentPath = join(
    process.cwd(),
    "ignition",
    "deployments",
    `chain-${SEPOLIA_CHAIN_ID}`,
    "deployed_addresses.json"
  );

  try {
    const content = readFileSync(deploymentPath, "utf-8");
    const addresses = JSON.parse(content);

    return {
      metaNodeToken: addresses["MetaNodeDeploy#MetaNodeToken"],
      metaNodeStake: addresses["MetaNodeDeploy#MetaNodeStake"],
      proxy: addresses["MetaNodeDeploy#proxy"],
      // 注意：ProxyStake 的 id 是 "ProxyStake"（大写 P），所以键名是 "MetaNodeDeploy#ProxyStake"
      proxyStake: addresses["MetaNodeDeploy#ProxyStake"],
    };
  } catch (error) {
    console.error(`无法读取部署地址文件: ${deploymentPath}`);
    console.error("请确保已运行部署脚本到 Sepolia 网络");
    throw error;
  }
}

// 获取合约 ABI
function getContractABI(contractName: string): any[] {
  // MetaNodeToken 在 MetaNode.sol 文件中
  const solFileName = contractName === "MetaNodeToken" ? "MetaNode.sol" : `${contractName}.sol`;
  
  const artifactPath = join(
    process.cwd(),
    "artifacts",
    "contracts",
    solFileName,
    `${contractName}.json`
  );

  try {
    const content = readFileSync(artifactPath, "utf-8");
    const artifact = JSON.parse(content);
    return artifact.abi;
  } catch (error) {
    console.error(`无法读取合约 ABI: ${artifactPath}`);
    throw error;
  }
}

// 重新分配测试币
async function redistributeTestETH(
  provider: ethers.Provider,
  wallets: ethers.Wallet[],
  targetBalance: bigint = ethers.parseEther("0.1")
): Promise<void> {
  console.log("\n开始重新分配测试币...");

  // 计算总余额
  let totalBalance = 0n;
  const balances: bigint[] = [];

  for (let i = 0; i < wallets.length; i++) {
    const balance = await provider.getBalance(wallets[i].address);
    balances.push(balance);
    totalBalance += balance;
    console.log(`钱包 ${i + 1} 余额: ${ethers.formatEther(balance)} ETH`);
  }

  console.log(`总余额: ${ethers.formatEther(totalBalance)} ETH`);

  // 计算每个钱包应该获得的余额（保留一些 gas 费）
  const perWallet = (totalBalance * 95n) / (BigInt(wallets.length) * 100n); // 保留 5% 作为 gas

  // 如果某个钱包余额不足，从余额最多的钱包转账
  for (let i = 0; i < wallets.length; i++) {
    const currentBalance = balances[i];
    if (currentBalance < targetBalance && perWallet >= targetBalance) {
      // 找到余额最多的钱包
      let maxBalanceIndex = 0;
      let maxBalance = balances[0];
      for (let j = 1; j < wallets.length; j++) {
        if (balances[j] > maxBalance) {
          maxBalance = balances[j];
          maxBalanceIndex = j;
        }
      }

      // 从余额最多的钱包转账（保留一些 gas 费）
      const needed = targetBalance - currentBalance;
      const gasReserve = ethers.parseEther("0.01"); // 保留 0.01 ETH 作为 gas
      if (balances[maxBalanceIndex] > needed + gasReserve) {
        try {
          const tx = await wallets[maxBalanceIndex].sendTransaction({
            to: wallets[i].address,
            value: needed,
          });
          console.log(
            `从钱包 ${maxBalanceIndex + 1} 转账 ${ethers.formatEther(needed)} ETH 到钱包 ${i + 1} (tx: ${tx.hash})`
          );
          await tx.wait();
          await delay(DELAY_MS); // 等待交易确认
          balances[i] += needed;
          balances[maxBalanceIndex] -= needed;
        } catch (error) {
          console.error(`转账失败: ${error}`);
        }
      }
    }
  }

  console.log("测试币分配完成\n");
}

describe("MetaNodeStake Sepolia 测试套件", function () {
  this.timeout(20 * 60 * 1000); // 20 分钟超时

  // 从环境变量获取配置
  const rpcUrl = process.env.SEPOLIA_RPC_URL;
  if (!rpcUrl) {
    throw new Error("未找到 SEPOLIA_RPC_URL 环境变量");
  }

  const privateKeys = [
    process.env.SEPOLIA_PRIVATE_KEY,
    process.env.SEPOLIA_PRIVATE_KEY_2,
    process.env.SEPOLIA_PRIVATE_KEY_3,
    process.env.SEPOLIA_PRIVATE_KEY_4,
  ].filter((key): key is string => !!key);

  if (privateKeys.length < 4) {
    throw new Error("需要至少 4 个私钥 (SEPOLIA_PRIVATE_KEY, SEPOLIA_PRIVATE_KEY_2, SEPOLIA_PRIVATE_KEY_3, SEPOLIA_PRIVATE_KEY_4)");
  }

  // 创建 provider 和 wallets
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const wallets = privateKeys.map((key) => new ethers.Wallet(key, provider));

  console.log("使用的钱包地址:");
  for (let i = 0; i < wallets.length; i++) {
    console.log(`钱包 ${i + 1}: ${wallets[i].address}`);
  }

  // 读取部署地址
  const deployedAddresses = getDeployedAddresses();
  console.log("\n部署的合约地址:");
  console.log("MetaNodeToken:", deployedAddresses.metaNodeToken);
  console.log("MetaNodeStake (Implementation):", deployedAddresses.metaNodeStake);
  console.log("Proxy:", deployedAddresses.proxy);
  console.log("ProxyStake (MetaNodeStake Interface):", deployedAddresses.proxyStake);

  // 使用 proxyStake 地址（基于代理地址的 MetaNodeStake 接口）
  // proxyStake 和 proxy 指向同一个地址，但 proxyStake 语义更清晰
  const proxyAddress = deployedAddresses.proxyStake || deployedAddresses.proxy;

  if (!deployedAddresses.metaNodeToken || !proxyAddress) {
    throw new Error("缺少必要的部署地址");
  }

  // 获取合约 ABI
  const metaNodeTokenABI = getContractABI("MetaNodeToken");
  const metaNodeStakeABI = getContractABI("MetaNodeStake");

  // 创建合约实例
  const metaNodeToken = new ethers.Contract(
    deployedAddresses.metaNodeToken,
    metaNodeTokenABI,
    provider
  );

  // 使用 proxyStake 地址创建 MetaNodeStake 合约实例
  // 这是代理地址 + MetaNodeStake ABI 的正确组合
  const metaNodeStake = new ethers.Contract(
    proxyAddress,
    metaNodeStakeABI,
    provider
  );

  // 在测试开始前设置
  before(async function () {
    this.timeout(10 * 60 * 1000); // 为 before 钩子单独设置超时
    // 重新分配测试币
    await redistributeTestETH(provider, wallets);

    // 等待延时
    console.log(`等待 ${DELAY_MS / 1000} 秒以适应 Sepolia 网络...`);
    await delay(DELAY_MS);
    console.log("延时结束，开始测试\n");
  });

  // 测试用例 1: 检查合约初始化状态
  it("检查合约初始化状态", async function () {
    const metaNodeAddress = await metaNodeStake.MetaNode();
    expect(metaNodeAddress.toLowerCase()).to.equal(
      deployedAddresses.metaNodeToken!.toLowerCase(),
      "MetaNode 代币地址不匹配"
    );

    const startBlock = await metaNodeStake.startBlock();
    const endBlock = await metaNodeStake.endBlock();
    const metaNodePerBlock = await metaNodeStake.MetaNodePerBlock();

    console.log("合约初始化状态:");
    console.log(`  startBlock: ${startBlock}`);
    console.log(`  endBlock: ${endBlock}`);
    console.log(`  metaNodePerBlock: ${ethers.formatEther(metaNodePerBlock)} MetaNode`);

    expect(Number(startBlock)).to.be.greaterThan(0, "startBlock 应该大于 0");
    expect(Number(endBlock)).to.be.greaterThan(0, "endBlock 应该大于 0");
    expect(Number(metaNodePerBlock)).to.be.greaterThan(0, "metaNodePerBlock 应该大于 0");
  });

  // 测试用例 2: 检查管理员角色
  it("检查管理员角色", async function () {
    const ADMIN_ROLE = await metaNodeStake.ADMIN_ROLE();
    const DEFAULT_ADMIN_ROLE = await metaNodeStake.DEFAULT_ADMIN_ROLE();

    // 检查第一个钱包是否有管理员角色
    const hasAdminRole = await metaNodeStake.hasRole(ADMIN_ROLE, wallets[0].address);
    const hasDefaultAdminRole = await metaNodeStake.hasRole(
      DEFAULT_ADMIN_ROLE,
      wallets[0].address
    );

    console.log(`钱包 1 (${wallets[0].address}) 角色:`);
    console.log(`  ADMIN_ROLE: ${hasAdminRole}`);
    console.log(`  DEFAULT_ADMIN_ROLE: ${hasDefaultAdminRole}`);

    // 至少应该有一个管理员
    expect(hasAdminRole || hasDefaultAdminRole, "部署账户应该有管理员角色").to.be.true;
  });

  // 测试用例 3: 检查池信息
  it("检查池信息", async function () {
    const poolLength = await metaNodeStake.poolLength();
    console.log(`池数量: ${poolLength}`);

    if (Number(poolLength) > 0) {
      const pool = await metaNodeStake.pool(0);
      console.log("池 0 信息:");
      console.log(`  stTokenAddress: ${pool.stTokenAddress}`);
      console.log(`  poolWeight: ${pool.poolWeight}`);
      console.log(`  stTokenAmount: ${ethers.formatEther(pool.stTokenAmount)}`);
      console.log(`  minDepositAmount: ${ethers.formatEther(pool.minDepositAmount)}`);
    }

    expect(Number(poolLength)).to.be.at.least(0, "池数量应该 >= 0");
  });

  // 测试用例 4: 测试 ETH 池存款（如果存在）
  it("测试 ETH 池存款", async function () {
    this.timeout(20 * 60 * 1000); // 设置超时
    const poolLength = await metaNodeStake.poolLength();
    if (Number(poolLength) === 0) {
      console.log("没有池，跳过存款测试");
      return;
    }

    const pool = await metaNodeStake.pool(0);
    const stTokenAddress = pool.stTokenAddress;

    // 检查是否是 ETH 池（地址为 0x0）
    if (stTokenAddress !== ethers.ZeroAddress) {
      console.log("池 0 不是 ETH 池，跳过 ETH 存款测试");
      return;
    }

    const depositAmount = ethers.parseEther("0.001");
    const minDeposit = pool.minDepositAmount;

    if (depositAmount < minDeposit) {
      console.log(`存款金额 ${ethers.formatEther(depositAmount)} 小于最小存款 ${ethers.formatEther(minDeposit)}，跳过测试`);
      return;
    }

    // 使用钱包 2 进行存款
    const wallet = wallets[1];
    const stakeWithSigner = metaNodeStake.connect(wallet);

    const balanceBefore = await provider.getBalance(wallet.address);
    const stakingBalanceBefore = await metaNodeStake.stakingBalance(0, wallet.address);

    console.log(`钱包 2 余额: ${ethers.formatEther(balanceBefore)} ETH`);
    console.log(`钱包 2 当前质押余额: ${ethers.formatEther(stakingBalanceBefore)} ETH`);

    // 执行存款
    const tx = await (stakeWithSigner as any).depositETH({ value: depositAmount });
    console.log(`存款交易已发送: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`存款交易已确认，区块: ${receipt?.blockNumber}`);

    // 等待延时
    await delay(DELAY_MS);

    // 检查质押余额
    const stakingBalanceAfter = await metaNodeStake.stakingBalance(0, wallet.address);
    console.log(`钱包 2 质押后余额: ${ethers.formatEther(stakingBalanceAfter)} ETH`);

    expect(stakingBalanceAfter).to.be.at.least(
      stakingBalanceBefore + depositAmount,
      "质押余额应该增加"
    );
  });

  // 测试用例 5: 测试领取奖励
  it("测试领取奖励", async function () {
    this.timeout(20 * 60 * 1000); // 设置超时
    const poolLength = await metaNodeStake.poolLength();
    if (Number(poolLength) === 0) {
      console.log("没有池，跳过领取奖励测试");
      return;
    }

    // 使用钱包 2 检查待领取奖励
    const wallet = wallets[1];
    const pending = await metaNodeStake.pendingMetaNode(0, wallet.address);
    console.log(`钱包 2 待领取奖励: ${ethers.formatEther(pending)} MetaNode`);

    if (pending === 0n) {
      console.log("没有待领取的奖励，跳过领取测试");
      return;
    }

    const stakeWithSigner = metaNodeStake.connect(wallet);
    const tokenBalanceBefore = await metaNodeToken.balanceOf(wallet.address);

    // 执行领取
    const tx = await (stakeWithSigner as any).claim(0);
    console.log(`领取交易已发送: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`领取交易已确认，区块: ${receipt?.blockNumber}`);

    // 等待延时
    await delay(DELAY_MS);

    // 检查代币余额
    const tokenBalanceAfter = await metaNodeToken.balanceOf(wallet.address);
    console.log(`钱包 2 MetaNode 余额: ${ethers.formatEther(tokenBalanceBefore)} -> ${ethers.formatEther(tokenBalanceAfter)}`);

    expect(tokenBalanceAfter).to.be.at.least(tokenBalanceBefore, "代币余额应该增加");
  });

  // 测试用例 6: 测试暂停功能（管理员）
  it("测试暂停功能", async function () {
    this.timeout(20 * 60 * 1000); // 设置超时
    const wallet = wallets[0]; // 使用第一个钱包（部署账户，应该是管理员）
    const stakeWithSigner = metaNodeStake.connect(wallet);

    // 检查当前暂停状态
    const depositPausedBefore = await metaNodeStake.depositPaused();
    const withdrawPausedBefore = await metaNodeStake.withdrawPaused();
    const claimPausedBefore = await metaNodeStake.claimPaused();

    console.log("当前暂停状态:");
    console.log(`  depositPaused: ${depositPausedBefore}`);
    console.log(`  withdrawPaused: ${withdrawPausedBefore}`);
    console.log(`  claimPaused: ${claimPausedBefore}`);

    // 测试暂停存款（如果未暂停）
    if (!depositPausedBefore) {
      const tx = await (stakeWithSigner as any).pauseDeposit();
      console.log(`暂停存款交易已发送: ${tx.hash}`);
      await tx.wait();
      await delay(DELAY_MS);

      const depositPausedAfter = await metaNodeStake.depositPaused();
      expect(depositPausedAfter).to.equal(true, "存款应该被暂停");

      // 恢复存款
      const tx2 = await (stakeWithSigner as any).unpauseDeposit();
      console.log(`恢复存款交易已发送: ${tx2.hash}`);
      await tx2.wait();
      await delay(DELAY_MS);

      const depositPausedRestored = await metaNodeStake.depositPaused();
      expect(depositPausedRestored).to.equal(false, "存款应该被恢复");
    }
  });

  after(function () {
    console.log("\n所有测试完成!");
  });
});

