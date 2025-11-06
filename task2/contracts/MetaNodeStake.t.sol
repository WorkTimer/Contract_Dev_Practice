// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MetaNodeStake} from "./MetaNodeStake.sol";
import {MetaNodeToken} from "./MetaNode.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 代币用于测试非 ETH 池
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 10000000 * 1e18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MetaNodeStakeTest is Test {
    MetaNodeStake public stake;
    MetaNodeToken public metaNodeToken;
    MockERC20 public stakingToken;
    
    address public owner = address(0x1);
    address public admin = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);

    uint256 public constant START_BLOCK = 100;
    uint256 public constant END_BLOCK = 10000;
    uint256 public constant META_NODE_PER_BLOCK = 1e18;
    uint256 public constant ETH_POOL_WEIGHT = 100;
    uint256 public constant ERC20_POOL_WEIGHT = 200;
    uint256 public constant MIN_DEPOSIT = 1e15; // 0.001 ETH/token
    uint256 public constant UNSTAKE_LOCKED_BLOCKS = 100;

    function setUp() public {
        // 设置区块号
        vm.roll(START_BLOCK);
        
        // 使用 owner 地址部署，确保 owner 拥有正确的角色
        vm.startPrank(owner);
        
        // 部署 MetaNode 代币（代币将铸造给 owner）
        metaNodeToken = new MetaNodeToken();
        
        // 部署实现合约
        MetaNodeStake implementation = new MetaNodeStake();
        
        // 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            MetaNodeStake.initialize.selector,
            metaNodeToken,
            START_BLOCK,
            END_BLOCK,
            META_NODE_PER_BLOCK
        );
        
        // 部署代理合约（msg.sender 将是 owner，owner 会被授予所有角色）
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        stake = MetaNodeStake(payable(address(proxy)));
        
        // 部署 Mock ERC20 代币
        stakingToken = new MockERC20("Staking Token", "ST");
        stakingToken.mint(user1, 10000 * 1e18);
        stakingToken.mint(user2, 10000 * 1e18);
        
        // 给 MetaNodeStake 合约转账足够的 MetaNode 代币用于奖励
        metaNodeToken.transfer(address(stake), 1000000 * 1e18);
        
        // 添加 ETH 池
        stake.addPool(address(0), ETH_POOL_WEIGHT, MIN_DEPOSIT, UNSTAKE_LOCKED_BLOCKS, false);
        
        // 添加 ERC20 池
        stake.addPool(address(stakingToken), ERC20_POOL_WEIGHT, MIN_DEPOSIT, UNSTAKE_LOCKED_BLOCKS, false);
        
        // 给 admin 授予 ADMIN_ROLE，让 admin 也能执行管理操作
        stake.grantRole(stake.ADMIN_ROLE(), admin);
        
        vm.stopPrank();
    }

    // ============ 初始化测试 ============
    
    function test_Initialization() public view {
        assertEq(address(stake.MetaNode()), address(metaNodeToken));
        assertEq(stake.startBlock(), START_BLOCK);
        assertEq(stake.endBlock(), END_BLOCK);
        assertEq(stake.MetaNodePerBlock(), META_NODE_PER_BLOCK);
        assertEq(stake.poolLength(), 2);
        assertEq(stake.totalPoolWeight(), ETH_POOL_WEIGHT + ERC20_POOL_WEIGHT);
    }

    // ============ ETH 存款测试 ============
    
    function test_DepositETH() public {
        vm.deal(user1, 10 ether);
        
        vm.prank(user1);
        stake.depositETH{value: 1 ether}();
        
        assertEq(stake.stakingBalance(0, user1), 1 ether);
        assertEq(address(stake).balance, 1 ether);
    }

    function test_DepositETH_AmountTooSmall() public {
        vm.deal(user1, 10 ether);
        
        vm.prank(user1);
        vm.expectRevert("deposit amount is too small");
        stake.depositETH{value: MIN_DEPOSIT - 1}();
    }

    function test_DepositETH_WhenPaused() public {
        vm.deal(user1, 10 ether);
        
        vm.prank(owner);
        stake.pauseDeposit();
        
        vm.prank(user1);
        vm.expectRevert("deposit is paused");
        stake.depositETH{value: 1 ether}();
    }

    // ============ ERC20 存款测试 ============
    
    function test_DepositERC20() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stake), 1000 * 1e18);
        stake.deposit(1, 1000 * 1e18);
        vm.stopPrank();
        
        assertEq(stake.stakingBalance(1, user1), 1000 * 1e18);
        assertEq(stakingToken.balanceOf(address(stake)), 1000 * 1e18);
    }

    function test_DepositERC20_AmountTooSmall() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stake), 1000 * 1e18);
        vm.expectRevert("deposit amount is too small");
        stake.deposit(1, MIN_DEPOSIT - 1);
        vm.stopPrank();
    }

    function test_DepositERC20_CannotDepositToETHPool() public {
        vm.deal(user1, 10 ether);
        
        vm.prank(user1);
        vm.expectRevert("deposit not support ETH staking");
        stake.deposit(0, 1 ether);
    }

    // ============ 解质押测试 ============
    
    function test_Unstake() public {
        // 先存款
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        stake.depositETH{value: 1 ether}();
        
        // 推进区块
        vm.roll(START_BLOCK + 10);
        
        // 解质押
        vm.prank(user1);
        stake.unstake(0, 0.5 ether);
        
        assertEq(stake.stakingBalance(0, user1), 0.5 ether);
        
        // 检查提取请求
        (uint256 requestAmount, ) = stake.withdrawAmount(0, user1);
        assertEq(requestAmount, 0.5 ether);
    }

    function test_Unstake_InsufficientBalance() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        stake.depositETH{value: 1 ether}();
        
        vm.prank(user1);
        vm.expectRevert("Not enough staking token balance");
        stake.unstake(0, 2 ether);
    }

    function test_Unstake_WhenPaused() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        stake.depositETH{value: 1 ether}();
        
        vm.prank(owner);
        stake.pauseWithdraw();
        
        vm.prank(user1);
        vm.expectRevert("withdraw is paused");
        stake.unstake(0, 0.5 ether);
    }

    // ============ 提取测试 ============
    
    function test_Withdraw() public {
        // 先存款
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        stake.depositETH{value: 1 ether}();
        
        uint256 balanceBefore = user1.balance;
        
        // 解质押
        vm.prank(user1);
        stake.unstake(0, 0.5 ether);
        
        // 推进足够的区块数以解锁
        vm.roll(block.number + UNSTAKE_LOCKED_BLOCKS + 1);
        
        // 提取
        vm.prank(user1);
        stake.withdraw(0);
        
        assertEq(user1.balance, balanceBefore + 0.5 ether);
        
        // 检查提取请求已清空
        (uint256 requestAmount, ) = stake.withdrawAmount(0, user1);
        assertEq(requestAmount, 0);
    }

    function test_Withdraw_BeforeUnlock() public {
        vm.deal(user1, 10 ether);
        uint256 balanceBefore = user1.balance;
        
        vm.prank(user1);
        stake.depositETH{value: 1 ether}();
        
        vm.prank(user1);
        stake.unstake(0, 0.5 ether);
        
        // 记录提取前的余额
        uint256 balanceBeforeWithdraw = user1.balance;
        
        // 不推进区块，立即尝试提取（应该不会提取任何东西）
        vm.prank(user1);
        stake.withdraw(0);
        
        // 余额应该保持不变，因为没有解锁的提取请求
        assertEq(user1.balance, balanceBeforeWithdraw);
        assertEq(user1.balance, balanceBefore - 1 ether); // 余额 = 10 - 1 = 9 ETH
    }

    // ============ 领取奖励测试 ============
    
    function test_Claim() public {
        // 先存款
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        stake.depositETH{value: 1 ether}();
        
        // 推进区块以产生奖励
        vm.roll(START_BLOCK + 100);
        
        uint256 pending = stake.pendingMetaNode(0, user1);
        assertGt(pending, 0);
        
        uint256 balanceBefore = metaNodeToken.balanceOf(user1);
        
        vm.prank(user1);
        stake.claim(0);
        
        uint256 balanceAfter = metaNodeToken.balanceOf(user1);
        assertGt(balanceAfter, balanceBefore);
    }

    function test_Claim_WhenPaused() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        stake.depositETH{value: 1 ether}();
        
        vm.roll(START_BLOCK + 100);
        
        vm.prank(owner);
        stake.pauseClaim();
        
        vm.prank(user1);
        vm.expectRevert("claim is paused");
        stake.claim(0);
    }

    function test_Claim_MultipleUsers() public {
        // 用户1 存款
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        stake.depositETH{value: 1 ether}();
        
        // 用户2 存款
        vm.deal(user2, 10 ether);
        vm.prank(user2);
        stake.depositETH{value: 2 ether}();
        
        // 推进区块
        vm.roll(START_BLOCK + 100);
        
        // 两个用户都领取
        vm.prank(user1);
        stake.claim(0);
        
        vm.prank(user2);
        stake.claim(0);
        
        uint256 user1Reward = metaNodeToken.balanceOf(user1);
        uint256 user2Reward = metaNodeToken.balanceOf(user2);
        
        // user2 的质押量是 user1 的 2 倍，应该获得大约 2 倍的奖励
        assertGt(user2Reward, user1Reward);
    }

    // ============ 池更新测试 ============
    
    function test_UpdatePool() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        stake.depositETH{value: 1 ether}();
        
        vm.roll(START_BLOCK + 50);
        
        vm.prank(owner);
        stake.updatePool(0);
        
        // 检查池已更新
        (,,uint256 lastRewardBlock,,,,) = stake.pool(0);
        assertEq(lastRewardBlock, block.number);
    }

    function test_MassUpdatePools() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        stake.depositETH{value: 1 ether}();
        
        vm.startPrank(user2);
        stakingToken.approve(address(stake), 1000 * 1e18);
        stake.deposit(1, 1000 * 1e18);
        vm.stopPrank();
        
        vm.roll(START_BLOCK + 50);
        
        stake.massUpdatePools();
        
        // 检查两个池都已更新
        (,,uint256 lastRewardBlock0,,,,) = stake.pool(0);
        (,,uint256 lastRewardBlock1,,,,) = stake.pool(1);
        assertEq(lastRewardBlock0, block.number);
        assertEq(lastRewardBlock1, block.number);
    }

    // ============ 管理功能测试 ============
    
    function test_SetMetaNodePerBlock() public {
        uint256 newRate = 2e18;
        
        vm.prank(owner);
        stake.setMetaNodePerBlock(newRate);
        
        assertEq(stake.MetaNodePerBlock(), newRate);
    }

    function test_SetStartBlock() public {
        uint256 newStartBlock = 200;
        
        vm.prank(owner);
        stake.setStartBlock(newStartBlock);
        
        assertEq(stake.startBlock(), newStartBlock);
    }

    function test_SetEndBlock() public {
        uint256 newEndBlock = 20000;
        
        vm.prank(owner);
        stake.setEndBlock(newEndBlock);
        
        assertEq(stake.endBlock(), newEndBlock);
    }

    function test_PauseAndUnpauseDeposit() public {
        vm.prank(owner);
        stake.pauseDeposit();
        assertTrue(stake.depositPaused());
        
        vm.prank(owner);
        stake.unpauseDeposit();
        assertFalse(stake.depositPaused());
    }

    function test_PauseAndUnpauseWithdraw() public {
        vm.prank(owner);
        stake.pauseWithdraw();
        assertTrue(stake.withdrawPaused());
        
        vm.prank(owner);
        stake.unpauseWithdraw();
        assertFalse(stake.withdrawPaused());
    }

    function test_PauseAndUnpauseClaim() public {
        vm.prank(owner);
        stake.pauseClaim();
        assertTrue(stake.claimPaused());
        
        vm.prank(owner);
        stake.unpauseClaim();
        assertFalse(stake.claimPaused());
    }

    // ============ Admin 角色测试 ============
    
    function test_AdminCanPauseDeposit() public {
        vm.prank(admin);
        stake.pauseDeposit();
        assertTrue(stake.depositPaused());
    }

    function test_AdminCanSetMetaNodePerBlock() public {
        uint256 newRate = 2e18;
        
        vm.prank(admin);
        stake.setMetaNodePerBlock(newRate);
        
        assertEq(stake.MetaNodePerBlock(), newRate);
    }

    function test_AdminCanSetPoolWeight() public {
        uint256 newWeight = 300;
        
        vm.prank(admin);
        stake.setPoolWeight(0, newWeight, false);
        
        (,uint256 poolWeight,,,,,) = stake.pool(0);
        assertEq(poolWeight, newWeight);
    }

    function test_AdminCannotGrantRole() public {
        // admin 只有 ADMIN_ROLE，没有 DEFAULT_ADMIN_ROLE，无法授予角色
        vm.prank(admin);
        vm.expectRevert();
        stake.grantRole(keccak256("admin_role"), user1);
    }

    // ============ 边界条件测试 ============
    
    function test_PendingMetaNode_NoStake() public view {
        uint256 pending = stake.pendingMetaNode(0, user1);
        assertEq(pending, 0);
    }

    function test_WithdrawAmount_NoRequests() public view {
        (uint256 requestAmount, uint256 pendingWithdraw) = stake.withdrawAmount(0, user1);
        assertEq(requestAmount, 0);
        assertEq(pendingWithdraw, 0);
    }

    function test_GetMultiplier() public view {
        uint256 multiplier = stake.getMultiplier(START_BLOCK, START_BLOCK + 100);
        assertEq(multiplier, 100 * META_NODE_PER_BLOCK);
    }

    function test_GetMultiplier_OutOfRange() public view {
        uint256 multiplier = stake.getMultiplier(START_BLOCK - 50, START_BLOCK + 100);
        // 应该从 START_BLOCK 开始计算
        assertEq(multiplier, 100 * META_NODE_PER_BLOCK);
        
        multiplier = stake.getMultiplier(START_BLOCK, END_BLOCK + 100);
        // 应该在 END_BLOCK 结束
        assertEq(multiplier, (END_BLOCK - START_BLOCK) * META_NODE_PER_BLOCK);
    }

    // ============ Fuzz 测试 ============
    
    function testFuzz_DepositAndUnstake(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, MIN_DEPOSIT, 100 ether);
        
        vm.deal(user1, depositAmount);
        vm.prank(user1);
        stake.depositETH{value: depositAmount}();
        
        assertEq(stake.stakingBalance(0, user1), depositAmount);
        
        // 解质押一部分
        uint256 unstakeAmount = depositAmount / 2;
        vm.prank(user1);
        stake.unstake(0, unstakeAmount);
        
        assertEq(stake.stakingBalance(0, user1), depositAmount - unstakeAmount);
    }

    function testFuzz_ClaimReward(uint256 blocksElapsed) public {
        blocksElapsed = bound(blocksElapsed, 1, 1000);
        
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        stake.depositETH{value: 1 ether}();
        
        vm.roll(START_BLOCK + blocksElapsed);
        
        uint256 pending = stake.pendingMetaNode(0, user1);
        
        vm.prank(user1);
        stake.claim(0);
        
        uint256 balance = metaNodeToken.balanceOf(user1);
        assertEq(balance, pending);
    }
}
