// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Arithmetic} from "../src/Arithmetic.sol";
import {ArithmeticOptimized1} from "../src/ArithmeticOptimized1.sol";
import {ArithmeticOptimized2} from "../src/ArithmeticOptimized2.sol";

/**
 * @title DeployArithmetic
 * @notice 部署脚本：演示如何使用 Forge Script 部署算术运算合约
 * @dev 可以部署所有三个版本的合约，用于对比测试
 */
contract DeployArithmetic is Script {
    function run() public {
        // 获取部署者私钥（从环境变量，如果没有则使用 Anvil 默认账户）
        uint256 deployerPrivateKey;
        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
        } catch {
            // 如果没有设置 PRIVATE_KEY，使用 Anvil 默认账户（用于本地测试）
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
            console.log("Using Anvil default account for local testing");
        }
        
        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying Arithmetic contracts...");
        console.log("Deployer address:", msg.sender);

        // 部署原始版本
        Arithmetic arithmetic = new Arithmetic();
        console.log("Arithmetic deployed at:", address(arithmetic));

        // 部署优化版本1
        ArithmeticOptimized1 arithmeticOpt1 = new ArithmeticOptimized1();
        console.log("ArithmeticOptimized1 deployed at:", address(arithmeticOpt1));

        // 部署优化版本2
        ArithmeticOptimized2 arithmeticOpt2 = new ArithmeticOptimized2();
        console.log("ArithmeticOptimized2 deployed at:", address(arithmeticOpt2));

        // 停止广播
        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("All contracts deployed successfully!");
    }

    /**
     * @notice 仅部署原始版本（用于测试）
     */
    function deployOriginal() public {
        uint256 deployerPrivateKey;
        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
        } catch {
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
        vm.startBroadcast(deployerPrivateKey);

        Arithmetic arithmetic = new Arithmetic();
        console.log("Arithmetic deployed at:", address(arithmetic));

        vm.stopBroadcast();
    }

    /**
     * @notice 仅部署优化版本1（用于测试）
     */
    function deployOptimized1() public {
        uint256 deployerPrivateKey;
        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
        } catch {
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
        vm.startBroadcast(deployerPrivateKey);

        ArithmeticOptimized1 arithmeticOpt1 = new ArithmeticOptimized1();
        console.log("ArithmeticOptimized1 deployed at:", address(arithmeticOpt1));

        vm.stopBroadcast();
    }

    /**
     * @notice 仅部署优化版本2（用于测试）
     */
    function deployOptimized2() public {
        uint256 deployerPrivateKey;
        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
        } catch {
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
        vm.startBroadcast(deployerPrivateKey);

        ArithmeticOptimized2 arithmeticOpt2 = new ArithmeticOptimized2();
        console.log("ArithmeticOptimized2 deployed at:", address(arithmeticOpt2));

        vm.stopBroadcast();
    }
}

