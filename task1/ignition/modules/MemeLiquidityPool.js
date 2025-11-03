// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("MemeLiquidityPoolModule", (m) => {
  // ============ Meme 代币部署参数 ============
  const memeName = m.getParameter("memeName", "Meme Token");
  const memeSymbol = m.getParameter("memeSymbol", "MEME");
  const memeTotalSupply = m.getParameter("memeTotalSupply", 1_000_000_000n * 10n ** 18n); // 10亿代币，18位小数
  const buyTaxRate = m.getParameter("buyTaxRate", 500n); // 5% (500 基点)
  const sellTaxRate = m.getParameter("sellTaxRate", 500n); // 5% (500 基点)
  const taxRecipient = m.getParameter("taxRecipient", m.getAccount(0)); // 默认使用部署者地址
  const maxTransactionAmount = m.getParameter("maxTransactionAmount", 10_000_000n * 10n ** 18n); // 单笔最大 1000万代币
  const dailyTransactionLimit = m.getParameter("dailyTransactionLimit", 50n); // 每日最多50次交易

  // ============ 部署 Meme 代币合约 ============
  const meme = m.contract("Meme", [
    memeName,
    memeSymbol,
    memeTotalSupply,
    buyTaxRate,
    sellTaxRate,
    taxRecipient,
    maxTransactionAmount,
    dailyTransactionLimit,
  ]);

  // ============ 部署流动性池合约 ============
  const liquidityPool = m.contract("LiquidityPool", [meme]);

  // ============ 配置合约关联关系 ============
  // 在 Meme 合约中设置流动性池地址
  m.call(meme, "setLiquidityPool", [liquidityPool]);

  // ============ 可选：取消暂停合约 ============
  // 如果需要部署后立即启用，可以取消注释以下两行
  // m.call(meme, "unpause");
  // m.call(liquidityPool, "unpause");

  return { 
    meme, 
    liquidityPool 
  };
});

