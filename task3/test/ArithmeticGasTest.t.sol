// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Arithmetic} from "../src/Arithmetic.sol";
import {ArithmeticOptimized1} from "../src/ArithmeticOptimized1.sol";
import {ArithmeticOptimized2} from "../src/ArithmeticOptimized2.sol";

/**
 * @title ArithmeticGasTest
 * @notice 测试三个版本的算术运算合约并比较 Gas 消耗
 */
contract ArithmeticGasTest is Test {
    Arithmetic public arithmetic;
    ArithmeticOptimized1 public arithmeticOpt1;
    ArithmeticOptimized2 public arithmeticOpt2;

    function setUp() public {
        arithmetic = new Arithmetic();
        arithmeticOpt1 = new ArithmeticOptimized1();
        arithmeticOpt2 = new ArithmeticOptimized2();
    }

    /**
     * @notice 测试加法运算的 Gas 消耗
     */
    function test_GasComparison_Add() public {
        uint256 a = 100;
        uint256 b = 50;

        console.log("\n=== Addition Gas Comparison ===");

        // 测试原始版本
        uint256 gasBefore1 = gasleft();
        arithmetic.add(a, b);
        uint256 gasUsed1 = gasBefore1 - gasleft();
        console.log("Original version Gas:", gasUsed1);

        // 测试优化版本1
        uint256 gasBefore2 = gasleft();
        arithmeticOpt1.add(a, b);
        uint256 gasUsed2 = gasBefore2 - gasleft();
        console.log("Optimized version 1 Gas:", gasUsed2);

        // 测试优化版本2
        uint256 gasBefore3 = gasleft();
        arithmeticOpt2.add(a, b);
        uint256 gasUsed3 = gasBefore3 - gasleft();
        console.log("Optimized version 2 Gas:", gasUsed3);

        // 验证结果一致性
        assertEq(arithmetic.result(), arithmeticOpt1.result(), "Results don't match");
        assertEq(arithmetic.result(), arithmeticOpt2.result(), "Results don't match");

        // 计算节省的 Gas
        console.log("\nGas Savings:");
        console.log("Optimized 1 saves:", gasUsed1 - gasUsed2);
        console.log("Optimized 2 saves:", gasUsed1 - gasUsed3);
        console.log("Optimized 2 vs Optimized 1 saves:", gasUsed2 - gasUsed3);
    }

    /**
     * @notice 测试减法运算的 Gas 消耗
     */
    function test_GasComparison_Subtract() public {
        uint256 a = 100;
        uint256 b = 30;

        console.log("\n=== Subtraction Gas Comparison ===");

        // 测试原始版本
        uint256 gasBefore1 = gasleft();
        arithmetic.subtract(a, b);
        uint256 gasUsed1 = gasBefore1 - gasleft();
        console.log("Original version Gas:", gasUsed1);

        // 测试优化版本1
        uint256 gasBefore2 = gasleft();
        arithmeticOpt1.subtract(a, b);
        uint256 gasUsed2 = gasBefore2 - gasleft();
        console.log("Optimized version 1 Gas:", gasUsed2);

        // 测试优化版本2
        uint256 gasBefore3 = gasleft();
        arithmeticOpt2.subtract(a, b);
        uint256 gasUsed3 = gasBefore3 - gasleft();
        console.log("Optimized version 2 Gas:", gasUsed3);

        // 验证结果一致性
        assertEq(arithmetic.result(), arithmeticOpt1.result(), "Results don't match");
        assertEq(arithmetic.result(), arithmeticOpt2.result(), "Results don't match");

        // 计算节省的 Gas
        console.log("\nGas Savings:");
        console.log("Optimized 1 saves:", gasUsed1 - gasUsed2);
        console.log("Optimized 2 saves:", gasUsed1 - gasUsed3);
        console.log("Optimized 2 vs Optimized 1 saves:", gasUsed2 - gasUsed3);
    }

    /**
     * @notice 测试乘法运算的 Gas 消耗
     */
    function test_GasComparison_Multiply() public {
        uint256 a = 10;
        uint256 b = 5;

        console.log("\n=== Multiplication Gas Comparison ===");

        // 测试原始版本
        uint256 gasBefore1 = gasleft();
        arithmetic.multiply(a, b);
        uint256 gasUsed1 = gasBefore1 - gasleft();
        console.log("Original version Gas:", gasUsed1);

        // 测试优化版本1
        uint256 gasBefore2 = gasleft();
        arithmeticOpt1.multiply(a, b);
        uint256 gasUsed2 = gasBefore2 - gasleft();
        console.log("Optimized version 1 Gas:", gasUsed2);

        // 测试优化版本2
        uint256 gasBefore3 = gasleft();
        arithmeticOpt2.multiply(a, b);
        uint256 gasUsed3 = gasBefore3 - gasleft();
        console.log("Optimized version 2 Gas:", gasUsed3);

        // 验证结果一致性
        assertEq(arithmetic.result(), arithmeticOpt1.result(), "Results don't match");
        assertEq(arithmetic.result(), arithmeticOpt2.result(), "Results don't match");

        // 计算节省的 Gas
        console.log("\nGas Savings:");
        console.log("Optimized 1 saves:", gasUsed1 - gasUsed2);
        console.log("Optimized 2 saves:", gasUsed1 - gasUsed3);
        console.log("Optimized 2 vs Optimized 1 saves:", gasUsed2 - gasUsed3);
    }

    /**
     * @notice 测试除法运算的 Gas 消耗
     */
    function test_GasComparison_Divide() public {
        uint256 a = 100;
        uint256 b = 5;

        console.log("\n=== Division Gas Comparison ===");

        // 测试原始版本
        uint256 gasBefore1 = gasleft();
        arithmetic.divide(a, b);
        uint256 gasUsed1 = gasBefore1 - gasleft();
        console.log("Original version Gas:", gasUsed1);

        // 测试优化版本1
        uint256 gasBefore2 = gasleft();
        arithmeticOpt1.divide(a, b);
        uint256 gasUsed2 = gasBefore2 - gasleft();
        console.log("Optimized version 1 Gas:", gasUsed2);

        // 测试优化版本2
        uint256 gasBefore3 = gasleft();
        arithmeticOpt2.divide(a, b);
        uint256 gasUsed3 = gasBefore3 - gasleft();
        console.log("Optimized version 2 Gas:", gasUsed3);

        // 验证结果一致性
        assertEq(arithmetic.result(), arithmeticOpt1.result(), "Results don't match");
        assertEq(arithmetic.result(), arithmeticOpt2.result(), "Results don't match");

        // 计算节省的 Gas
        console.log("\nGas Savings:");
        console.log("Optimized 1 saves:", gasUsed1 - gasUsed2);
        console.log("Optimized 2 saves:", gasUsed1 - gasUsed3);
        console.log("Optimized 2 vs Optimized 1 saves:", gasUsed2 - gasUsed3);
    }

    /**
     * @notice 测试除零错误处理
     */
    function test_DivisionByZero() public {
        // 测试原始版本
        vm.expectRevert("Arithmetic: division by zero");
        arithmetic.divide(10, 0);

        // 测试优化版本1
        vm.expectRevert("Arithmetic: division by zero");
        arithmeticOpt1.divide(10, 0);

        // 测试优化版本2（使用自定义错误）
        vm.expectRevert(ArithmeticOptimized2.DivisionByZero.selector);
        arithmeticOpt2.divide(10, 0);
    }

    /**
     * @notice 测试多次操作的累计 Gas 消耗
     */
    function test_GasComparison_MultipleOperations() public {
        console.log("\n=== Multiple Operations Gas Comparison ===");

        // 重置所有合约
        arithmetic.reset();
        arithmeticOpt1.reset();
        arithmeticOpt2.reset();

        // 原始版本
        uint256 gasBefore1 = gasleft();
        arithmetic.add(10, 20);
        arithmetic.subtract(50, 15);
        arithmetic.multiply(5, 6);
        arithmetic.divide(100, 4);
        uint256 gasUsed1 = gasBefore1 - gasleft();
        console.log("Original version total Gas:", gasUsed1);

        // 优化版本1
        uint256 gasBefore2 = gasleft();
        arithmeticOpt1.add(10, 20);
        arithmeticOpt1.subtract(50, 15);
        arithmeticOpt1.multiply(5, 6);
        arithmeticOpt1.divide(100, 4);
        uint256 gasUsed2 = gasBefore2 - gasleft();
        console.log("Optimized version 1 total Gas:", gasUsed2);

        // 优化版本2
        uint256 gasBefore3 = gasleft();
        arithmeticOpt2.add(10, 20);
        arithmeticOpt2.subtract(50, 15);
        arithmeticOpt2.multiply(5, 6);
        arithmeticOpt2.divide(100, 4);
        uint256 gasUsed3 = gasBefore3 - gasleft();
        console.log("Optimized version 2 total Gas:", gasUsed3);

        // 验证结果一致性
        assertEq(arithmetic.result(), arithmeticOpt1.result(), "Results don't match");
        assertEq(arithmetic.result(), arithmeticOpt2.result(), "Results don't match");

        // 计算节省的 Gas
        console.log("\nTotal Gas Savings:");
        console.log("Optimized 1 saves:", gasUsed1 - gasUsed2);
        console.log("Optimized 2 saves:", gasUsed1 - gasUsed3);
        console.log("Optimized 2 vs Optimized 1 saves:", gasUsed2 - gasUsed3);
    }

    /**
     * @notice 测试基本功能正确性
     */
    function test_Arithmetic_BasicFunctionality() public {
        // 测试原始版本
        assertEq(arithmetic.add(10, 5), 15);
        assertEq(arithmetic.result(), 15);
        
        assertEq(arithmetic.subtract(20, 8), 12);
        assertEq(arithmetic.result(), 12);
        
        assertEq(arithmetic.multiply(3, 4), 12);
        assertEq(arithmetic.result(), 12);
        
        assertEq(arithmetic.divide(100, 4), 25);
        assertEq(arithmetic.result(), 25);
        
        arithmetic.reset();
        assertEq(arithmetic.result(), 0);
        assertEq(arithmetic.operationCount(), 0);
    }

    /**
     * @notice 测试优化版本1的基本功能
     */
    function test_ArithmeticOptimized1_BasicFunctionality() public {
        assertEq(arithmeticOpt1.add(10, 5), 15);
        assertEq(arithmeticOpt1.result(), 15);
        
        assertEq(arithmeticOpt1.subtract(20, 8), 12);
        assertEq(arithmeticOpt1.result(), 12);
        
        assertEq(arithmeticOpt1.multiply(3, 4), 12);
        assertEq(arithmeticOpt1.result(), 12);
        
        assertEq(arithmeticOpt1.divide(100, 4), 25);
        assertEq(arithmeticOpt1.result(), 25);
        
        arithmeticOpt1.reset();
        assertEq(arithmeticOpt1.result(), 0);
        assertEq(arithmeticOpt1.operationCount(), 0);
    }

    /**
     * @notice 测试优化版本2的基本功能
     */
    function test_ArithmeticOptimized2_BasicFunctionality() public {
        assertEq(arithmeticOpt2.add(10, 5), 15);
        assertEq(arithmeticOpt2.result(), 15);
        
        assertEq(arithmeticOpt2.subtract(20, 8), 12);
        assertEq(arithmeticOpt2.result(), 12);
        
        assertEq(arithmeticOpt2.multiply(3, 4), 12);
        assertEq(arithmeticOpt2.result(), 12);
        
        assertEq(arithmeticOpt2.divide(100, 4), 25);
        assertEq(arithmeticOpt2.result(), 25);
        
        arithmeticOpt2.reset();
        assertEq(arithmeticOpt2.result(), 0);
        assertEq(arithmeticOpt2.operationCount(), 0);
    }

    /**
     * @notice 使用 Fuzz 测试验证所有版本的一致性
     */
    function testFuzz_AllVersionsConsistent(uint256 a, uint256 b) public {
        // 限制输入范围以避免溢出
        a = bound(a, 0, type(uint128).max);
        b = bound(b, 0, type(uint128).max);
        
        // 测试加法
        if (a + b <= type(uint128).max) {
            uint256 result1 = arithmetic.add(a, b);
            uint256 result2 = arithmeticOpt1.add(a, b);
            uint256 result3 = arithmeticOpt2.add(a, b);
            assertEq(result1, result2);
            assertEq(result1, result3);
        }
        
        // 重置
        arithmetic.reset();
        arithmeticOpt1.reset();
        arithmeticOpt2.reset();
        
        // 测试减法（确保 a >= b）
        if (a >= b) {
            uint256 result1 = arithmetic.subtract(a, b);
            uint256 result2 = arithmeticOpt1.subtract(a, b);
            uint256 result3 = arithmeticOpt2.subtract(a, b);
            assertEq(result1, result2);
            assertEq(result1, result3);
        }
        
        // 重置
        arithmetic.reset();
        arithmeticOpt1.reset();
        arithmeticOpt2.reset();
        
        // 测试除法（确保 b > 0）
        if (b > 0) {
            uint256 result1 = arithmetic.divide(a, b);
            uint256 result2 = arithmeticOpt1.divide(a, b);
            uint256 result3 = arithmeticOpt2.divide(a, b);
            assertEq(result1, result2);
            assertEq(result1, result3);
        }
    }
}

