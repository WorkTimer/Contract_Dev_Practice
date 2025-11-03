const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Liquidity Pool", function () {
  let meme;
  let liquidityPool;
  let owner;
  let user1;
  let user2;
  let taxRecipient;
  
  const TOTAL_SUPPLY = ethers.parseEther("1000000");
  const BUY_TAX_RATE = 500; // 5%
  const SELL_TAX_RATE = 500; // 5%
  const MAX_TRANSACTION_AMOUNT = ethers.parseEther("100000");
  const DAILY_TRANSACTION_LIMIT = 100;

  beforeEach(async function () {
    [owner, user1, user2, taxRecipient] = await ethers.getSigners();

    // 部署 Meme 代币
    const Meme = await ethers.getContractFactory("Meme");
    meme = await Meme.deploy(
      "Test Meme",
      "MEME",
      TOTAL_SUPPLY,
      BUY_TAX_RATE,
      SELL_TAX_RATE,
      taxRecipient.address,
      MAX_TRANSACTION_AMOUNT,
      DAILY_TRANSACTION_LIMIT
    );

    // 部署流动性池
    const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
    liquidityPool = await LiquidityPool.deploy(await meme.getAddress());

    // 设置流动性池地址到 Meme 合约
    await meme.setLiquidityPool(await liquidityPool.getAddress());

    // 取消暂停
    await meme.unpause();
    await liquidityPool.unpause();

    // 给用户1一些代币和ETH用于测试
    await meme.transfer(user1.address, ethers.parseEther("100000"));
    await owner.sendTransaction({
      to: user1.address,
      value: ethers.parseEther("10")
    });
  });

  describe("部署", function () {
    it("应该正确设置初始参数", async function () {
      expect(await liquidityPool.memeToken()).to.equal(await meme.getAddress());
      expect(await liquidityPool.reserveMeme()).to.equal(0);
      expect(await liquidityPool.reservePair()).to.equal(0);
      expect(await liquidityPool.totalLiquiditySupply()).to.equal(0);
      expect(await liquidityPool.tradingFee()).to.equal(30); // 默认 0.3%
      // 注意：在 beforeEach 中已经 unpause 了，所以这里不检查暂停状态
      // 如果需要检查初始暂停状态，应该在部署后立即检查，而不是在 beforeEach 后
    });

    it("不应该直接接收ETH", async function () {
      await expect(
        owner.sendTransaction({
          to: await liquidityPool.getAddress(),
          value: ethers.parseEther("1")
        })
      ).to.be.revertedWith("Use addLiquidity() or swapEthForMeme() to send ETH");
    });
  });

  describe("添加流动性", function () {
    it("应该能够首次添加流动性", async function () {
      const memeAmount = ethers.parseEther("10000");
      const ethAmount = ethers.parseEther("1");

      await meme.connect(user1).approve(await liquidityPool.getAddress(), memeAmount);
      
      await expect(
        liquidityPool.connect(user1).addLiquidity(memeAmount, { value: ethAmount })
      ).to.emit(liquidityPool, "LiquidityAdded");

      expect(await liquidityPool.reserveMeme()).to.equal(memeAmount);
      expect(await liquidityPool.reservePair()).to.equal(ethAmount);
      expect(await liquidityPool.totalLiquiditySupply()).to.be.gt(0);
      expect(await liquidityPool.liquidityBalances(user1.address)).to.be.gt(0);
    });

    it("后续添加流动性应该按比例计算", async function () {
      // 首次添加
      const memeAmount1 = ethers.parseEther("10000");
      const ethAmount1 = ethers.parseEther("1");
      await meme.connect(user1).approve(await liquidityPool.getAddress(), memeAmount1);
      await liquidityPool.connect(user1).addLiquidity(memeAmount1, { value: ethAmount1 });

      // 第二次添加
      const memeAmount2 = ethers.parseEther("5000");
      const ethAmount2 = ethers.parseEther("0.5");
      await meme.transfer(user2.address, memeAmount2);
      await meme.connect(user2).approve(await liquidityPool.getAddress(), memeAmount2);
      await owner.sendTransaction({
        to: user2.address,
        value: ethAmount2
      });
      
      await liquidityPool.connect(user2).addLiquidity(memeAmount2, { value: ethAmount2 });

      const user2Liquidity = await liquidityPool.liquidityBalances(user2.address);
      expect(user2Liquidity).to.be.gt(0);
    });

    it("添加流动性时应该要求两个金额都大于0", async function () {
      await meme.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("1000"));
      
      await expect(
        liquidityPool.connect(user1).addLiquidity(0, { value: ethers.parseEther("1") })
      ).to.be.revertedWith("Amounts must be greater than 0");

      await expect(
        liquidityPool.connect(user1).addLiquidity(ethers.parseEther("1000"), { value: 0 })
      ).to.be.revertedWith("Amounts must be greater than 0");
    });
  });

  describe("移除流动性", function () {
    beforeEach(async function () {
      // 先添加一些流动性
      const memeAmount = ethers.parseEther("10000");
      const ethAmount = ethers.parseEther("1");
      await meme.connect(user1).approve(await liquidityPool.getAddress(), memeAmount);
      await liquidityPool.connect(user1).addLiquidity(memeAmount, { value: ethAmount });
    });

    it("应该能够移除流动性", async function () {
      const userLiquidity = await liquidityPool.liquidityBalances(user1.address);
      expect(userLiquidity).to.be.gt(0);

      const initialMemeBalance = await meme.balanceOf(user1.address);
      const initialEthBalance = await ethers.provider.getBalance(user1.address);

      await expect(
        liquidityPool.connect(user1).removeLiquidity(userLiquidity)
      ).to.emit(liquidityPool, "LiquidityRemoved");

      const finalMemeBalance = await meme.balanceOf(user1.address);
      const finalEthBalance = await ethers.provider.getBalance(user1.address);

      expect(finalMemeBalance).to.be.gt(initialMemeBalance);
      expect(finalEthBalance).to.be.gt(initialEthBalance);
    });

    it("不应该移除超过自己拥有的流动性", async function () {
      const userLiquidity = await liquidityPool.liquidityBalances(user1.address);
      
      await expect(
        liquidityPool.connect(user2).removeLiquidity(userLiquidity)
      ).to.be.revertedWith("Insufficient liquidity balance");
    });

    it("应该能够部分移除流动性", async function () {
      const userLiquidity = await liquidityPool.liquidityBalances(user1.address);
      const removeAmount = userLiquidity / BigInt(2);

      await liquidityPool.connect(user1).removeLiquidity(removeAmount);

      expect(await liquidityPool.liquidityBalances(user1.address)).to.equal(userLiquidity - removeAmount);
    });
  });

  describe("交换功能", function () {
    beforeEach(async function () {
      // 先添加流动性
      const memeAmount = ethers.parseEther("100000");
      const ethAmount = ethers.parseEther("10");
      await meme.connect(user1).approve(await liquidityPool.getAddress(), memeAmount);
      await liquidityPool.connect(user1).addLiquidity(memeAmount, { value: ethAmount });
    });

    it("应该能够用ETH购买Meme代币", async function () {
      const ethIn = ethers.parseEther("1");
      const initialMemeBalance = await meme.balanceOf(user2.address);

      await expect(
        liquidityPool.connect(user2).swapEthForMeme(0, { value: ethIn })
      ).to.emit(liquidityPool, "TokenSwapped");

      const finalMemeBalance = await meme.balanceOf(user2.address);
      expect(finalMemeBalance).to.be.gt(initialMemeBalance);

      // 储备量应该更新
      const reserves = await liquidityPool.getReserves();
      expect(reserves[1]).to.be.gt(ethers.parseEther("10")); // ETH储备增加
      expect(reserves[0]).to.be.lt(ethers.parseEther("100000")); // Meme储备减少
    });

    it("应该能够用Meme代币购买ETH", async function () {
      const memeIn = ethers.parseEther("10000");
      await meme.transfer(user2.address, memeIn);
      await meme.connect(user2).approve(await liquidityPool.getAddress(), memeIn);

      const initialEthBalance = await ethers.provider.getBalance(user2.address);

      await expect(
        liquidityPool.connect(user2).swapMemeForEth(memeIn, 0)
      ).to.emit(liquidityPool, "TokenSwapped");

      const finalEthBalance = await ethers.provider.getBalance(user2.address);
      expect(finalEthBalance).to.be.gt(initialEthBalance);
    });

    it("应该检查最小输出金额（滑点保护）", async function () {
      const ethIn = ethers.parseEther("1");
      const minMemeOut = ethers.parseEther("999999"); // 不合理的滑点保护

      await expect(
        liquidityPool.connect(user2).swapEthForMeme(minMemeOut, { value: ethIn })
      ).to.be.revertedWith("Insufficient output amount");
    });

    it("交换时应该收取交易手续费", async function () {
      const ethIn = ethers.parseEther("1");
      const reservesBefore = await liquidityPool.getReserves();

      await liquidityPool.connect(user2).swapEthForMeme(0, { value: ethIn });

      const reservesAfter = await liquidityPool.getReserves();
      // ETH储备应该增加，但少于全额（因为扣除了手续费）
      expect(reservesAfter[1]).to.be.lt(reservesBefore[1] + ethIn);
    });
  });

  describe("计算函数", function () {
    beforeEach(async function () {
      // 先添加流动性
      const memeAmount = ethers.parseEther("100000");
      const ethAmount = ethers.parseEther("10");
      await meme.connect(user1).approve(await liquidityPool.getAddress(), memeAmount);
      await liquidityPool.connect(user1).addLiquidity(memeAmount, { value: ethAmount });
    });

    it("应该能够计算添加流动性后的LP代币数量", async function () {
      const memeAmount = ethers.parseEther("10000");
      const ethAmount = ethers.parseEther("1");

      const liquidity = await liquidityPool.calculateLiquidityTokens(memeAmount, ethAmount);
      expect(liquidity).to.be.gt(0);
    });

    it("应该能够计算移除流动性后的代币数量", async function () {
      const userLiquidity = await liquidityPool.liquidityBalances(user1.address);
      
      const [memeAmount, ethAmount] = await liquidityPool.calculateRemoveLiquidity(userLiquidity);
      expect(memeAmount).to.be.gt(0);
      expect(ethAmount).to.be.gt(0);
    });

    it("应该能够计算交换输出数量（ETH输入）", async function () {
      const ethIn = ethers.parseEther("1");
      
      const [amountOut, priceImpact] = await liquidityPool.getAmountOut(
        ethers.ZeroAddress,
        ethIn
      );
      
      expect(amountOut).to.be.gt(0);
      expect(priceImpact).to.be.gt(0);
    });

    it("应该能够计算交换输出数量（Meme代币输入）", async function () {
      const memeIn = ethers.parseEther("10000");
      
      const [amountOut, priceImpact] = await liquidityPool.getAmountOut(
        await meme.getAddress(),
        memeIn
      );
      
      expect(amountOut).to.be.gt(0);
      expect(priceImpact).to.be.gt(0);
    });

    it("应该能够获取池子信息", async function () {
      const info = await liquidityPool.getPoolInfo();
      
      expect(info[0]).to.be.gt(0); // reserveMeme
      expect(info[1]).to.be.gt(0); // reservePair
      expect(info[2]).to.be.gt(0); // totalLiquiditySupply
      expect(info[3]).to.equal(30); // tradingFee
      expect(info[4]).to.be.gt(0); // price
      expect(info[5]).to.be.false; // isPaused
    });

    it("应该能够获取用户流动性信息", async function () {
      const info = await liquidityPool.getUserLiquidityInfo(user1.address);
      
      expect(info[0]).to.be.gt(0); // liquidityBalance
      expect(info[1]).to.be.gt(0); // memeValue
      expect(info[2]).to.be.gt(0); // pairValue
      expect(info[3]).to.be.gt(0); // share
    });

    it("在没有流动性时应该返回零值", async function () {
      // 创建一个新的流动性池（没有添加任何流动性）
      const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
      const newPool = await LiquidityPool.deploy(await meme.getAddress());
      
      // 查询用户信息（应该是零值）
      const info = await newPool.getUserLiquidityInfo(user1.address);
      
      expect(info[0]).to.equal(0); // liquidityBalance
      expect(info[1]).to.equal(0); // memeValue
      expect(info[2]).to.equal(0); // pairValue
      expect(info[3]).to.equal(0); // share
    });
  });

  describe("管理员功能", function () {
    it("所有者应该能够暂停合约", async function () {
      await liquidityPool.pause();
      expect(await liquidityPool.paused()).to.be.true;
    });

    it("所有者应该能够取消暂停", async function () {
      await liquidityPool.pause();
      await liquidityPool.unpause();
      expect(await liquidityPool.paused()).to.be.false;
    });

    it("非所有者不应该能够暂停", async function () {
      await expect(
        liquidityPool.connect(user1).pause()
      ).to.be.revertedWithCustomError(liquidityPool, "OwnableUnauthorizedAccount");
    });

    it("所有者应该能够设置交易手续费", async function () {
      const newFee = 50; // 0.5%
      await liquidityPool.setTradingFee(newFee);
      
      expect(await liquidityPool.tradingFee()).to.equal(newFee);
    });

    it("不应该设置过高的手续费", async function () {
      await expect(
        liquidityPool.setTradingFee(1001) // 超过10%
      ).to.be.revertedWith("Fee should not exceed 10% for safety");
    });

    it("暂停时不应该允许添加流动性", async function () {
      await liquidityPool.pause();
      
      const memeAmount = ethers.parseEther("10000");
      const ethAmount = ethers.parseEther("1");
      await meme.connect(user1).approve(await liquidityPool.getAddress(), memeAmount);

      await expect(
        liquidityPool.connect(user1).addLiquidity(memeAmount, { value: ethAmount })
      ).to.be.revertedWithCustomError(liquidityPool, "EnforcedPause");
    });
  });

  describe("最小流动性", function () {
    it("首次添加流动性时应该锁定最小流动性", async function () {
      const memeAmount = ethers.parseEther("10000");
      const ethAmount = ethers.parseEther("1");

      await meme.connect(user1).approve(await liquidityPool.getAddress(), memeAmount);
      await liquidityPool.connect(user1).addLiquidity(memeAmount, { value: ethAmount });

      expect(await liquidityPool.totalLiquiditySupply()).to.be.gte(
        await liquidityPool.MINIMUM_LIQUIDITY()
      );
    });

    it("完全移除流动性后应该保留最小流动性", async function () {
      const memeAmount = ethers.parseEther("10000");
      const ethAmount = ethers.parseEther("1");

      await meme.connect(user1).approve(await liquidityPool.getAddress(), memeAmount);
      await liquidityPool.connect(user1).addLiquidity(memeAmount, { value: ethAmount });

      const userLiquidity = await liquidityPool.liquidityBalances(user1.address);
      await liquidityPool.connect(user1).removeLiquidity(userLiquidity);

      // 应该还保留最小流动性
      expect(await liquidityPool.totalLiquiditySupply()).to.equal(
        await liquidityPool.MINIMUM_LIQUIDITY()
      );
    });
  });
});

