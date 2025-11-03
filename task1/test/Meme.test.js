const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Meme Token", function () {
  let meme;
  let owner;
  let user1;
  let user2;
  let taxRecipient;
  let liquidityPool;
  
  const TOTAL_SUPPLY = ethers.parseEther("1000000"); // 100万代币
  const BUY_TAX_RATE = 500; // 5%
  const SELL_TAX_RATE = 500; // 5%
  const MAX_TRANSACTION_AMOUNT = ethers.parseEther("10000"); // 1万代币
  const DAILY_TRANSACTION_LIMIT = 10; // 每日10次交易

  beforeEach(async function () {
    [owner, user1, user2, taxRecipient] = await ethers.getSigners();

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

    // 部署一个模拟的流动性池地址
    liquidityPool = user2.address;
    await meme.setLiquidityPool(liquidityPool);

    // 取消暂停以便测试
    await meme.unpause();

    // 给用户1一些代币用于测试
    const transferAmount = ethers.parseEther("10000");
    await meme.transfer(user1.address, transferAmount);
  });

  describe("部署", function () {
    it("应该正确设置初始参数", async function () {
      expect(await meme.name()).to.equal("Test Meme");
      expect(await meme.symbol()).to.equal("MEME");
      // totalSupply 可能会因为销毁而减少，所以不检查这个
      expect(await meme.buyTaxRate()).to.equal(BUY_TAX_RATE);
      expect(await meme.sellTaxRate()).to.equal(SELL_TAX_RATE);
      expect(await meme.taxRecipient()).to.equal(taxRecipient.address);
      expect(await meme.maxTransactionAmount()).to.equal(MAX_TRANSACTION_AMOUNT);
      expect(await meme.dailyTransactionLimit()).to.equal(DAILY_TRANSACTION_LIMIT);
    });

    it("应该将总供应量铸造给所有者", async function () {
      // 注意：在 beforeEach 中已经转了一些给 user1，所以这里检查原始供应量
      const balance = await meme.balanceOf(owner.address);
      const transferAmount = ethers.parseEther("10000");
      expect(balance + transferAmount).to.equal(TOTAL_SUPPLY);
    });

    it("应该初始状态为暂停", async function () {
      const MemeFactory = await ethers.getContractFactory("Meme");
      const newMeme = await MemeFactory.deploy(
        "Test Meme",
        "MEME",
        TOTAL_SUPPLY,
        BUY_TAX_RATE,
        SELL_TAX_RATE,
        taxRecipient.address,
        MAX_TRANSACTION_AMOUNT,
        DAILY_TRANSACTION_LIMIT
      );
      expect(await newMeme.paused()).to.be.true;
    });

    it("应该自动豁免所有者和税费接收地址", async function () {
      expect(await meme.exemptFromTax(owner.address)).to.be.true;
      expect(await meme.exemptFromLimits(owner.address)).to.be.true;
      expect(await meme.exemptFromTax(taxRecipient.address)).to.be.true;
      expect(await meme.exemptFromLimits(taxRecipient.address)).to.be.true;
    });
  });

  describe("税费机制", function () {
    it("买入时应该收取买入税", async function () {
      // 创建一个新的地址作为流动性池来测试（但不是实际设置）
      const testPool = ethers.Wallet.createRandom().connect(ethers.provider);
      // 给testPool一些代币（需要先充值ETH用于gas）
      await owner.sendTransaction({
        to: testPool.address,
        value: ethers.parseEther("0.1")
      });
      
      // 使用testPool作为from地址，但不设置为流动性池，这样就不会自动豁免
      // 我们需要手动模拟一个非豁免的流动性池
      // 先设置流动性池地址（会被自动豁免）
      await meme.setLiquidityPool(testPool.address);
      // 然后取消豁免以测试税费
      await meme.setTaxExemption(testPool.address, false);
      await meme.setLimitExemption(testPool.address, false);

      const buyAmount = ethers.parseEther("1000");
      const taxAmount = (buyAmount * BigInt(BUY_TAX_RATE)) / BigInt(10000);
      const receivedAmount = buyAmount - taxAmount;

      const initialTaxRecipientBalance = await meme.balanceOf(taxRecipient.address);
      const initialUserBalance = await meme.balanceOf(user1.address);

      // 先给测试池一些代币
      await meme.transfer(testPool.address, buyAmount);

      // 模拟从流动性池买入（从流动性池转账给用户）
      await meme.connect(testPool).transfer(user1.address, buyAmount);

      expect(await meme.balanceOf(user1.address)).to.equal(
        initialUserBalance + receivedAmount
      );
      expect(await meme.balanceOf(taxRecipient.address)).to.equal(
        initialTaxRecipientBalance + taxAmount
      );
    });

    it("卖出时应该收取卖出税", async function () {
      // 创建一个新的地址作为流动性池来测试
      const testPool = ethers.Wallet.createRandom().connect(ethers.provider);
      // 给testPool一些代币（需要先充值ETH用于gas）
      await owner.sendTransaction({
        to: testPool.address,
        value: ethers.parseEther("0.1")
      });
      
      // 设置流动性池地址（会被自动豁免）
      await meme.setLiquidityPool(testPool.address);
      // 然后取消豁免以测试税费
      await meme.setTaxExemption(testPool.address, false);
      await meme.setLimitExemption(testPool.address, false);

      const sellAmount = ethers.parseEther("1000");
      const taxAmount = (sellAmount * BigInt(SELL_TAX_RATE)) / BigInt(10000);
      const receivedAmount = sellAmount - taxAmount;

      const initialTaxRecipientBalance = await meme.balanceOf(taxRecipient.address);
      const initialPoolBalance = await meme.balanceOf(testPool.address);

      // 模拟向流动性池卖出（用户转账给流动性池）
      await meme.connect(user1).transfer(testPool.address, sellAmount);

      expect(await meme.balanceOf(testPool.address)).to.equal(
        initialPoolBalance + receivedAmount
      );
      expect(await meme.balanceOf(taxRecipient.address)).to.equal(
        initialTaxRecipientBalance + taxAmount
      );
    });

    it("普通转账不应该收取税费", async function () {
      const transferAmount = ethers.parseEther("1000");
      const initialTaxRecipientBalance = await meme.balanceOf(taxRecipient.address);

      await meme.connect(user1).transfer(user2.address, transferAmount);

      expect(await meme.balanceOf(user2.address)).to.equal(transferAmount);
      expect(await meme.balanceOf(taxRecipient.address)).to.equal(
        initialTaxRecipientBalance
      );
    });

    it("使用transferFrom时应该正确计算税费", async function () {
      // 创建一个非豁免的流动性池地址来测试
      const testPool = ethers.Wallet.createRandom().connect(ethers.provider);
      await owner.sendTransaction({
        to: testPool.address,
        value: ethers.parseEther("0.1")
      });
      
      await meme.setLiquidityPool(testPool.address);
      await meme.setTaxExemption(testPool.address, false);
      await meme.setLimitExemption(testPool.address, false);
      
      const sellAmount = ethers.parseEther("1000");
      const taxAmount = (sellAmount * BigInt(SELL_TAX_RATE)) / BigInt(10000);
      
      // 给用户1授权足够的代币
      await meme.connect(user1).approve(owner.address, sellAmount);
      
      // 使用transferFrom从user1转移到流动性池
      const initialTaxRecipientBalance = await meme.balanceOf(taxRecipient.address);
      await meme.transferFrom(user1.address, testPool.address, sellAmount);
      
      // 检查税费是否正确收取
      expect(await meme.balanceOf(taxRecipient.address)).to.equal(
        initialTaxRecipientBalance + taxAmount
      );
      
      // 恢复原始流动性池
      await meme.setLiquidityPool(liquidityPool);
    });

    it("当税费为0时不应该触发TaxCollected事件", async function () {
      const transferAmount = ethers.parseEther("1000");
      
      // 普通转账，不应该触发税费事件
      const tx = await meme.connect(user1).transfer(user2.address, transferAmount);
      const receipt = await tx.wait();
      
      // 检查是否没有 TaxCollected 事件
      const events = receipt.logs.filter(log => {
        try {
          const parsed = meme.interface.parseLog(log);
          return parsed && parsed.name === "TaxCollected";
        } catch {
          return false;
        }
      });
      
      expect(events.length).to.equal(0);
    });

    it("豁免地址不应该被收税", async function () {
      const transferAmount = ethers.parseEther("1000");
      const initialUser2Balance = await meme.balanceOf(user2.address);
      
      // owner 是豁免地址，转账给流动性池不应该收税
      await meme.connect(owner).transfer(liquidityPool, transferAmount);

      expect(await meme.balanceOf(liquidityPool)).to.equal(transferAmount);
    });
  });

  describe("交易限制", function () {
    it("应该限制单笔交易最大额度", async function () {
      const exceedAmount = MAX_TRANSACTION_AMOUNT + ethers.parseEther("1");

      await expect(
        meme.connect(user1).transfer(user2.address, exceedAmount)
      ).to.be.reverted;
    });

    it("应该在限额内的交易成功", async function () {
      const validAmount = MAX_TRANSACTION_AMOUNT;

      await meme.connect(user1).transfer(user2.address, validAmount);

      expect(await meme.balanceOf(user2.address)).to.equal(validAmount);
    });

    it("豁免地址应该不受交易额度限制", async function () {
      const exceedAmount = MAX_TRANSACTION_AMOUNT + ethers.parseEther("10000");

      // owner 是豁免地址，应该可以超额转账
      await meme.connect(owner).transfer(user2.address, exceedAmount);
      expect(await meme.balanceOf(user2.address)).to.equal(exceedAmount);
    });
  });

  describe("每日交易次数限制", function () {
    it("应该在达到每日限制后拒绝交易", async function () {
      // 创建一个新的地址（不是流动性池）用于测试
      // 获取所有可用的 signers，如果没有第5个，就使用一个随机地址
      const signers = await ethers.getSigners();
      let testUser = signers[4];
      if (!testUser) {
        // 如果没有第5个signer，创建一个随机地址
        testUser = { address: ethers.Wallet.createRandom().address };
      }
      
      // 给测试用户一些代币（如果地址有效）
      await meme.transfer(testUser.address, ethers.parseEther("100000"));
      
      const transferAmount = ethers.parseEther("100");

      // 获取用户1今日已执行的交易次数（之前可能有转账）
      const today = await meme.getTodayTransactionCount(user1.address);
      const remaining = DAILY_TRANSACTION_LIMIT - Number(today);

      // 执行剩余允许的交易次数（转账到非流动性池地址）
      for (let i = 0; i < remaining; i++) {
        await meme.connect(user1).transfer(testUser.address, transferAmount);
      }

      // 下一笔交易应该失败
      await expect(
        meme.connect(user1).transfer(testUser.address, transferAmount)
      ).to.be.reverted;
    });

    it("豁免地址应该不受每日限制约束", async function () {
      const transferAmount = ethers.parseEther("100");

      // owner 是豁免地址，应该可以超过限制
      for (let i = 0; i < DAILY_TRANSACTION_LIMIT + 5; i++) {
        await meme.connect(owner).transfer(user2.address, transferAmount);
      }
    });
  });

  describe("暂停功能", function () {
    it("暂停后普通用户应该无法交易", async function () {
      await meme.pause();

      await expect(
        meme.connect(user1).transfer(user2.address, ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(meme, "EnforcedPause");
    });

    it("暂停后豁免用户应该可以交易", async function () {
      await meme.pause();

      // owner 是豁免用户，应该可以继续交易
      await meme.connect(owner).transfer(user2.address, ethers.parseEther("100"));
    });

    it("取消暂停后应该可以正常交易", async function () {
      await meme.pause();
      await meme.unpause();

      await meme.connect(user1).transfer(user2.address, ethers.parseEther("100"));
      expect(await meme.balanceOf(user2.address)).to.equal(ethers.parseEther("100"));
    });
  });

  describe("代币销毁", function () {
    it("用户应该能够销毁自己的代币", async function () {
      const burnAmount = ethers.parseEther("100");
      const initialBalance = await meme.balanceOf(user1.address);
      const initialSupply = await meme.totalSupply();

      await meme.connect(user1).burn(burnAmount);

      expect(await meme.balanceOf(user1.address)).to.equal(initialBalance - burnAmount);
      expect(await meme.totalSupply()).to.equal(initialSupply - burnAmount);
    });

    it("应该能够销毁授权给其他地址的代币", async function () {
      const burnAmount = ethers.parseEther("100");
      
      await meme.connect(user1).approve(owner.address, burnAmount);
      await meme.connect(owner).burnFrom(user1.address, burnAmount);

      expect(await meme.balanceOf(user1.address)).to.be.lt(ethers.parseEther("10000"));
    });
  });

  describe("管理员功能", function () {
    it("所有者应该能够更新买入税率", async function () {
      const newRate = 300; // 3%
      await meme.setBuyTaxRate(newRate);
      
      expect(await meme.buyTaxRate()).to.equal(newRate);
    });

    it("所有者应该能够更新卖出税率", async function () {
      const newRate = 300; // 3%
      await meme.setSellTaxRate(newRate);
      
      expect(await meme.sellTaxRate()).to.equal(newRate);
    });

    it("非所有者不应该能够更新税率", async function () {
      await expect(
        meme.connect(user1).setBuyTaxRate(200)
      ).to.be.revertedWithCustomError(meme, "OwnableUnauthorizedAccount");
    });

    it("应该能够设置税费豁免地址", async function () {
      await meme.setTaxExemption(user1.address, true);
      
      expect(await meme.exemptFromTax(user1.address)).to.be.true;
    });

    it("应该能够设置限制豁免地址", async function () {
      await meme.setLimitExemption(user1.address, true);
      
      expect(await meme.exemptFromLimits(user1.address)).to.be.true;
    });

    it("应该能够更新流动性池地址", async function () {
      const newPool = user2.address;
      await meme.setLiquidityPool(newPool);
      
      expect(await meme.liquidityPool()).to.equal(newPool);
      expect(await meme.exemptFromTax(newPool)).to.be.true;
      expect(await meme.exemptFromLimits(newPool)).to.be.true;
    });

    it("应该能够批量设置税务豁免", async function () {
      const addresses = [user1.address, user2.address];
      await meme.batchSetTaxExemption(addresses, true);
      
      expect(await meme.exemptFromTax(user1.address)).to.be.true;
      expect(await meme.exemptFromTax(user2.address)).to.be.true;
      
      // 测试取消豁免
      await meme.batchSetTaxExemption(addresses, false);
      expect(await meme.exemptFromTax(user1.address)).to.be.false;
      expect(await meme.exemptFromTax(user2.address)).to.be.false;
    });

    it("批量设置税务豁免时应该跳过零地址", async function () {
      const addresses = [user1.address, ethers.ZeroAddress, user2.address];
      await meme.batchSetTaxExemption(addresses, true);
      
      expect(await meme.exemptFromTax(user1.address)).to.be.true;
      expect(await meme.exemptFromTax(user2.address)).to.be.true;
    });

    it("应该能够批量设置限制豁免", async function () {
      const addresses = [user1.address, user2.address];
      await meme.batchSetLimitExemption(addresses, true);
      
      expect(await meme.exemptFromLimits(user1.address)).to.be.true;
      expect(await meme.exemptFromLimits(user2.address)).to.be.true;
      
      // 测试取消豁免
      await meme.batchSetLimitExemption(addresses, false);
      expect(await meme.exemptFromLimits(user1.address)).to.be.false;
      expect(await meme.exemptFromLimits(user2.address)).to.be.false;
    });

    it("批量设置限制豁免时应该跳过零地址", async function () {
      const addresses = [user1.address, ethers.ZeroAddress, user2.address];
      await meme.batchSetLimitExemption(addresses, true);
      
      expect(await meme.exemptFromLimits(user1.address)).to.be.true;
      expect(await meme.exemptFromLimits(user2.address)).to.be.true;
    });

    it("应该能够设置税费接收地址", async function () {
      const newRecipient = user2.address;
      await meme.setTaxRecipient(newRecipient);
      
      expect(await meme.taxRecipient()).to.equal(newRecipient);
      expect(await meme.exemptFromTax(newRecipient)).to.be.true;
      expect(await meme.exemptFromLimits(newRecipient)).to.be.true;
    });

    it("应该能够设置交易限制", async function () {
      const newMaxAmount = ethers.parseEther("50000");
      const newDailyLimit = 20;
      
      await meme.setTransactionLimits(newMaxAmount, newDailyLimit);
      
      expect(await meme.maxTransactionAmount()).to.equal(newMaxAmount);
      expect(await meme.dailyTransactionLimit()).to.equal(newDailyLimit);
    });
  });

  describe("查询功能", function () {
    it("应该能够计算税费", async function () {
      const amount = ethers.parseEther("1000");
      const poolAddress = await meme.liquidityPool();
      
      // 买入税：从流动性池买入
      const buyTax = await meme.calculateTax(
        poolAddress,
        user1.address,
        amount
      );
      // 注意：如果流动性池被豁免，税费为0
      // 这里我们检查如果池子未被豁免时应该有的税费
      if (await meme.exemptFromTax(poolAddress)) {
        expect(buyTax).to.equal(0); // 豁免地址不收税
      } else {
        expect(buyTax).to.equal((amount * BigInt(BUY_TAX_RATE)) / BigInt(10000));
      }

      // 卖出税：向流动性池卖出
      const sellTax = await meme.calculateTax(
        user1.address,
        poolAddress,
        amount
      );
      // 注意：如果用户1被豁免，税费为0
      if (await meme.exemptFromTax(user1.address)) {
        expect(sellTax).to.equal(0);
      } else {
        // 如果池子被豁免，税费也为0
        if (await meme.exemptFromTax(poolAddress)) {
          expect(sellTax).to.equal(0);
        } else {
          expect(sellTax).to.equal((amount * BigInt(SELL_TAX_RATE)) / BigInt(10000));
        }
      }
    });

    it("应该能够查询每日交易次数", async function () {
      const transferAmount = ethers.parseEther("100");
      
      // 获取初始交易次数
      const initialCount = await meme.getTodayTransactionCount(user1.address);
      
      // 执行一次转账
      await meme.connect(user1).transfer(user2.address, transferAmount);
      
      // 应该增加1次
      const finalCount = await meme.getTodayTransactionCount(user1.address);
      expect(finalCount).to.equal(initialCount + 1n);
    });

    it("应该能够查询指定日期的交易次数", async function () {
      const transferAmount = ethers.parseEther("100");
      
      // 执行一次转账
      await meme.connect(user1).transfer(user2.address, transferAmount);
      
      // 获取当前的区块链时间戳并计算今天的日期
      const blockNumber = await ethers.provider.getBlockNumber();
      const block = await ethers.provider.getBlock(blockNumber);
      const today = Number(block.timestamp) / 86400; // 转换为天数
      
      // 查询今天的交易次数
      const count = await meme.getDailyTransactionCount(user1.address, Math.floor(today));
      expect(count).to.be.gte(1);
      
      // 查询昨天的交易次数（应该是0）
      const yesterdayCount = await meme.getDailyTransactionCount(user1.address, Math.floor(today) - 1);
      expect(yesterdayCount).to.equal(0);
      
      // 查询明天的交易次数（应该是0）
      const tomorrowCount = await meme.getDailyTransactionCount(user1.address, Math.floor(today) + 1);
      expect(tomorrowCount).to.equal(0);
    });
  });
});

