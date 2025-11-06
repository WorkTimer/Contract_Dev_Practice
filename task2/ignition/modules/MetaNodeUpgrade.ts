import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import MetaNodeDeploy from "./MetaNodeDeploy.js";

/**
 * MetaNodeStake 升级模块
 * 
 * 将 MetaNodeStake 代理合约升级为 MetaNodeStakeV2
 * 
 * 工作原理：
 * - 自动从已部署的 MetaNodeDeploy 模块获取代理合约地址
 * - 无需手动指定地址，Hardhat Ignition 会自动从部署记录中读取
 * 
 * 使用方式：
 * ```bash
 * npx hardhat ignition deploy ignition/modules/MetaNodeUpgrade.ts --network sepolia
 * ```
 * 
 * 注意：
 * - 确保已先运行 MetaNodeDeploy 部署到对应网络
 * - 确保部署账户具有 UPGRADE_ROLE 权限
 * - 升级后代理合约地址保持不变，但实现合约指向 V2
 */
export default buildModule("MetaNodeUpgrade", (m) => {
  // 从已部署的 MetaNodeDeploy 模块获取代理合约引用
  // useModule 会自动处理：
  // - 如果 MetaNodeDeploy 已部署，从部署记录中读取并返回已部署的合约引用
  // - 如果未部署，会先部署 MetaNodeDeploy，然后返回新的合约引用
  // 使用 proxyStake，它是 MetaNodeStake 接口的合约引用（通过代理地址）
  const { proxyStake } = m.useModule(MetaNodeDeploy);
  
  // 直接使用 useModule 返回的 proxyStake
  // proxyStake 已经是 MetaNodeStake 接口的合约引用，可以直接用于调用函数
  const proxy = proxyStake;
  
  // 1. 部署 MetaNodeStakeV2 实现合约
  const v2Implementation = m.contract("MetaNodeStakeV2");

  // 2. 引用已部署的代理合约（已在上面完成）

  // 3. 调用升级函数
  // upgradeToAndCall 需要两个参数：
  // - newImplementation: 新的实现合约地址
  // - data: 初始化数据（可选，这里使用空数据 "0x"）
  m.call(proxy, "upgradeToAndCall", [v2Implementation, "0x"]);

  return {
    v2Implementation,
    proxy,
  };
});

