// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title ArithmeticOptimized2
 * @notice 第二个优化版本：使用自定义错误和打包变量
 * @dev 优化策略：
 *      1. 使用自定义错误替代 require 字符串（节省 Gas）
 *      2. 将多个小变量打包到一个存储槽中（uint128 + uint128 = 一个存储槽）
 *      3. 使用 unchecked 块减少溢出检查开销
 *      4. 移除不必要的字符串存储
 */
contract ArithmeticOptimized2 {
    // 自定义错误比 require 字符串更节省 Gas（不需要存储字符串）
    error SubtractionUnderflow();
    error DivisionByZero();

    // 打包变量：将 operationCount (uint128) 和 result (uint128) 打包到一个存储槽
    // 这样可以减少存储操作，节省 Gas（两个 uint128 可以放在一个 256 位存储槽中）
    struct PackedData {
        uint128 result;
        uint128 operationCount;
    }

    PackedData public packedData;

    /**
     * @notice 执行加法运算（优化版本2）
     * @param a 第一个操作数
     * @param b 第二个操作数
     * @return 计算结果
     */
    function add(uint256 a, uint256 b) public returns (uint256) {
        unchecked {
            uint256 sum = a + b;
            // 使用打包结构减少存储操作
            PackedData memory data = packedData;
            // 注意：如果 sum 超过 uint128，这里会截断，但为了演示打包优化
            // 在实际应用中，如果值可能很大，应该使用 uint256
            data.result = uint128(sum);
            data.operationCount++;
            packedData = data;
            
            return sum;
        }
    }

    /**
     * @notice 执行减法运算（优化版本2）
     * @param a 被减数
     * @param b 减数
     * @return 计算结果
     */
    function subtract(uint256 a, uint256 b) public returns (uint256) {
        unchecked {
            if (a < b) revert SubtractionUnderflow(); // 自定义错误，节省 Gas
            uint256 diff = a - b;
            
            PackedData memory data = packedData;
            data.result = uint128(diff);
            data.operationCount++;
            packedData = data;
            
            return diff;
        }
    }

    /**
     * @notice 执行乘法运算（优化版本2）
     * @param a 第一个操作数
     * @param b 第二个操作数
     * @return 计算结果
     */
    function multiply(uint256 a, uint256 b) public returns (uint256) {
        unchecked {
            uint256 product = a * b;
            
            PackedData memory data = packedData;
            data.result = uint128(product);
            data.operationCount++;
            packedData = data;
            
            return product;
        }
    }

    /**
     * @notice 执行除法运算（优化版本2）
     * @param a 被除数
     * @param b 除数
     * @return 计算结果
     */
    function divide(uint256 a, uint256 b) public returns (uint256) {
        // 使用自定义错误替代 require 字符串
        if (b == 0) revert DivisionByZero();
        
        unchecked {
            uint256 quotient = a / b;
            
            PackedData memory data = packedData;
            data.result = uint128(quotient);
            data.operationCount++;
            packedData = data;
            
            return quotient;
        }
    }

    /**
     * @notice 重置结果和操作计数（优化版本2）
     */
    function reset() public {
        packedData = PackedData(0, 0);
    }

    /**
     * @notice 获取结果
     */
    function result() public view returns (uint256) {
        return packedData.result;
    }

    /**
     * @notice 获取操作计数
     */
    function operationCount() public view returns (uint256) {
        return packedData.operationCount;
    }
}

