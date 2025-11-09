// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title Arithmetic
 * @notice 原始未优化版本的算术运算合约
 * @dev 包含基本的加法和减法运算，未进行任何优化
 */
contract Arithmetic {
    uint256 public result;
    uint256 public operationCount;
    string public lastOperation;

    /**
     * @notice 执行加法运算
     * @param a 第一个操作数
     * @param b 第二个操作数
     * @return 计算结果
     */
    function add(uint256 a, uint256 b) public returns (uint256) {
        require(a + b >= a, "Arithmetic: addition overflow");
        result = a + b;
        operationCount = operationCount + 1;
        lastOperation = "add";
        return result;
    }

    /**
     * @notice 执行减法运算
     * @param a 被减数
     * @param b 减数
     * @return 计算结果
     */
    function subtract(uint256 a, uint256 b) public returns (uint256) {
        require(a >= b, "Arithmetic: subtraction underflow");
        result = a - b;
        operationCount = operationCount + 1;
        lastOperation = "subtract";
        return result;
    }

    /**
     * @notice 执行乘法运算
     * @param a 第一个操作数
     * @param b 第二个操作数
     * @return 计算结果
     */
    function multiply(uint256 a, uint256 b) public returns (uint256) {
        require(a == 0 || (a * b) / a == b, "Arithmetic: multiplication overflow");
        result = a * b;
        operationCount = operationCount + 1;
        lastOperation = "multiply";
        return result;
    }

    /**
     * @notice 执行除法运算
     * @param a 被除数
     * @param b 除数
     * @return 计算结果
     */
    function divide(uint256 a, uint256 b) public returns (uint256) {
        require(b > 0, "Arithmetic: division by zero");
        result = a / b;
        operationCount = operationCount + 1;
        lastOperation = "divide";
        return result;
    }

    /**
     * @notice 重置结果和操作计数
     */
    function reset() public {
        result = 0;
        operationCount = 0;
        lastOperation = "";
    }
}

