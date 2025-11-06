import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MetaNodeDeploy", (m) => {
  // 使用 getParameter 获取部署参数，提供默认值
  // 部署时可以通过参数覆盖这些值
  const startBlock = m.getParameter("startBlock", 100n);
  const endBlock = m.getParameter("endBlock", 10000n);
  // metaNodePerBlock 使用 wei 单位，默认 1 ether
  // 如需覆盖，传入 bigint 值（以 wei 为单位）
  const metaNodePerBlock = m.getParameter("metaNodePerBlock", 1000000000000000000n);

  // 1. 部署 MetaNodeToken
  const metaNodeToken = m.contract("MetaNodeToken");

  // 2. 部署 MetaNodeStake 实现合约
  const metaNodeStake = m.contract("MetaNodeStake");

  // 3. 使用 encodeFunctionCall 编码初始化数据
  // Ignition 会在部署时解析 Future 对象并生成正确的编码数据
  const initData = m.encodeFunctionCall(metaNodeStake, "initialize", [
    metaNodeToken,
    startBlock,
    endBlock,
    metaNodePerBlock,
  ]);

  // 4. 部署 ERC1967Proxy
  const proxy = m.contract("ERC1967Proxy", [
    metaNodeStake,
    initData,
  ]);

  // 5. 使用代理地址创建 MetaNodeStake 接口实例
  // 这样返回的对象可以直接调用 MetaNodeStake 的方法
  // 注意：需要提供唯一的 id，避免与上面的 metaNodeStake 冲突
  const proxyStake = m.contractAt("MetaNodeStake", proxy, { id: "ProxyStake" });

  return {
    metaNodeToken,
    metaNodeStake,
    proxy,
    proxyStake,
  };
});

