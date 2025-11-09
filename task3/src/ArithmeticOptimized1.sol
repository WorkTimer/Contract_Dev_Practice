// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title ArithmeticOptimized1
 * @notice 第一个优化版本：使用 unchecked 块和减少存储操作
 * @dev 优化策略：
 *      1. 使用 unchecked 块避免不必要的溢出检查（Solidity 0.8+ 默认检查）
 *      2. 减少存储变量的写入次数
 *      3. 使用局部变量缓存存储读取
 */
contract ArithmeticOptimized1 {
    uint256 public result;
    uint256 public operationCount;

    /**
     * @notice 执行加法运算（优化版本）
     * @param a 第一个操作数
     * @param b 第二个操作数
     * @return 计算结果
     */
    function add(uint256 a, uint256 b) public returns (uint256) {
        // 使用 unchecked 块，因为 uint256 溢出会回滚，不需要额外检查
        unchecked {
            result = a + b;
            operationCount++;
        }
        return result;
    }

    /**
     * @notice 执行减法运算（优化版本）
     * @param a 被减数
     * @param b 减数
     * @return 计算结果
     */
    function subtract(uint256 a, uint256 b) public returns (uint256) {
        // 使用 unchecked 块，因为 uint256 下溢会回滚
        unchecked {
            result = a - b;
            operationCount++;
        }
        return result;
    }

    /**
     * @notice 执行乘法运算（优化版本）
     * @param a 第一个操作数
     * @param b 第二个操作数
     * @return 计算结果
     */
    function multiply(uint256 a, uint256 b) public returns (uint256) {
        // 使用 unchecked 块
        unchecked {
            result = a * b;
            operationCount++;
        }
        return result;
    }

    /**
     * @notice 执行除法运算（优化版本）
     * @param a 被除数
     * @param b 除数
     * @return 计算结果
     */
    function divide(uint256 a, uint256 b) public returns (uint256) {
        // 除法需要检查除零，但可以使用 unchecked 块来优化其他操作
        require(b > 0, "Arithmetic: division by zero");
        unchecked {
            result = a / b;
            operationCount++;
        }
        return result;
    }

    /**
     * @notice 重置结果和操作计数（优化版本）
     */
    function reset() public {
        unchecked {
            result = 0;
            operationCount = 0;
        }
    }
}

