// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./MetaNodeStake.sol";

/**
 * @title MetaNodeStakeV2
 * @notice 升级版本合约，用于测试 UUPS 升级功能
 * @dev 此合约继承 MetaNodeStake，添加了 version() 函数来标识版本
 *      注意：升级合约时不能改变存储布局
 */
contract MetaNodeStakeV2 is MetaNodeStake {
    /**
     * @notice 返回合约版本号
     * @return 版本字符串 "V2.0"
     */
    function version() external pure returns (string memory) {
        return "V2.0";
    }
}