// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./Meme.sol";

/**
 * @title Liquidity Pool
 * @dev 简化的流动性池合约，用于与 Meme 代币集成
 * @notice 实现流动性提供、移除和交易功能
 * @notice 使用原生 ETH 作为配对代币（不再需要 ERC20 配对代币）
 */
contract LiquidityPool is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // ============ 状态变量 ============
    
    /**
     * @dev Meme 代币合约实例（作为 IERC20 使用）
     */
    IERC20 public memeToken;
    
    /**
     * @dev Meme 代币合约实例（用于调用 Meme 特有方法）
     */
    Meme public memeTokenContract;
    
    /**
     * @dev 池子中 Meme 代币的储备量
     */
    uint256 public reserveMeme;
    
    /**
     * @dev 池子中 ETH 的储备量（wei）
     */
    uint256 public reservePair;
    
    /**
     * @dev 总流动性代币供应量（LP Token）
     * @notice 用于跟踪流动性提供者份额
     */
    uint256 public totalLiquiditySupply;
    
    /**
     * @dev 每个地址提供的流动性代币数量
     */
    mapping(address => uint256) public liquidityBalances;
    
    /**
     * @dev 交易手续费率（以基点为单位，10000 = 100%）
     * @notice 例如：30 = 0.3%，默认值为 30 (0.3%)
     * @notice 可以通过 setTradingFee 函数修改，但受限于安全上限
     */
    uint256 public tradingFee = 30; // 0.3%
    
    /**
     * @dev 最小流动性要求（防止首次提供流动性时出现问题）
     */
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    
    // ============ 事件 ============
    
    /**
     * @dev 当流动性被添加时触发
     */
    event LiquidityAdded(
        address indexed provider,
        uint256 memeAmount,
        uint256 pairAmount,
        uint256 liquidityTokens
    );
    
    /**
     * @dev 当流动性被移除时触发
     */
    event LiquidityRemoved(
        address indexed provider,
        uint256 memeAmount,
        uint256 pairAmount,
        uint256 liquidityTokens
    );
    
    /**
     * @dev 当代币被交换时触发
     */
    event TokenSwapped(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    
    /**
     * @dev 当储备量更新时触发
     */
    event ReservesUpdated(uint256 reserveMeme, uint256 reservePair);
    
    /**
     * @dev 当交易手续费率改变时触发
     */
    event TradingFeeChanged(uint256 oldFee, uint256 newFee);
    
    // ============ 构造函数 ============
    
    /**
     * @dev 初始化流动性池合约
     * @param _memeToken Meme 代币合约地址
     * @notice 配对代币使用原生 ETH
     */
    constructor(address _memeToken) Ownable(msg.sender) {
        require(_memeToken != address(0), "Meme token cannot be zero address");
        
        memeToken = IERC20(_memeToken);
        memeTokenContract = Meme(_memeToken);
        
        // 初始状态为暂停，需要手动调用 unpause() 来启用
        _pause();
    }
    
    /**
     * @dev 拒绝直接接收 ETH
     * @notice 防止用户直接向合约发送 ETH，避免 ETH 余额与储备量不一致
     * @notice 必须通过 addLiquidity() 或 swapEthForMeme() 函数来使用 ETH
     */
    receive() external payable {
        revert("Use addLiquidity() or swapEthForMeme() to send ETH");
    }
    
    // ============ 核心功能函数 ============
    
    /**
     * @dev 添加流动性到池子
     * @param memeAmount 要添加的 Meme 代币数量
     * @return liquidityTokens 返回的流动性代币数量
     * @notice 首次添加流动性时，会按照实际金额创建 LP token
     *         后续添加时会根据当前储备量比例计算应得的 LP token
     * @notice 配对代币使用原生 ETH，通过 msg.value 接收
     */
    function addLiquidity(uint256 memeAmount) 
        external 
        payable
        whenNotPaused
        nonReentrant 
        returns (uint256 liquidityTokens) 
    {
        uint256 pairAmount = msg.value;
        require(memeAmount > 0 && pairAmount > 0, "Amounts must be greater than 0");
        
        // 转移 Meme 代币到池子
        memeToken.safeTransferFrom(msg.sender, address(this), memeAmount);
        // ETH 已通过 msg.value 自动转入合约
        
        uint256 liquidity;
        uint256 actualMemeAmount = memeAmount;
        uint256 actualPairAmount = pairAmount;
        
        // 如果是首次添加流动性
        if (totalLiquiditySupply == 0) {
            // 首次添加时，LP token 数量 = sqrt(memeAmount * pairAmount) - MINIMUM_LIQUIDITY
            // MINIMUM_LIQUIDITY 被永久锁定，防止首次 LP 被完全移除
            liquidity = Math.sqrt(memeAmount * pairAmount) - MINIMUM_LIQUIDITY;
            totalLiquiditySupply = MINIMUM_LIQUIDITY; // 永久锁定最小流动性
            // 首次添加流动性时使用全部代币，不需要退还
        } else {
            // 计算应该发放的流动性代币数量
            // liquidity = (memeAmount / reserveMeme) * totalLiquiditySupply
            // 为了简化，使用较小的比例
            uint256 liquidityFromMeme = (memeAmount * totalLiquiditySupply) / reserveMeme;
            uint256 liquidityFromPair = (pairAmount * totalLiquiditySupply) / reservePair;
            
            // 取较小的值，确保比例正确
            liquidity = liquidityFromMeme < liquidityFromPair 
                ? liquidityFromMeme 
                : liquidityFromPair;
            
            // 根据实际发放的 LP token 数量，倒推实际需要的代币数量
            actualMemeAmount = (liquidity * reserveMeme) / totalLiquiditySupply;
            actualPairAmount = (liquidity * reservePair) / totalLiquiditySupply;
            
            // 计算多余的代币数量并退还
            uint256 excessMeme = memeAmount - actualMemeAmount;
            uint256 excessPair = pairAmount - actualPairAmount;
            
            if (excessMeme > 0) {
                memeToken.safeTransfer(msg.sender, excessMeme);
            }
            if (excessPair > 0) {
                // 退还多余的 ETH
                (bool success, ) = payable(msg.sender).call{value: excessPair}("");
                require(success, "ETH transfer failed");
            }
        }
        
        require(liquidity > 0, "Insufficient liquidity minted");
        
        // 更新储备量（只使用实际使用的代币数量）
        reserveMeme += actualMemeAmount;
        reservePair += actualPairAmount;
        
        // 更新流动性代币供应量
        totalLiquiditySupply += liquidity;
        liquidityBalances[msg.sender] += liquidity;
        
        emit LiquidityAdded(msg.sender, actualMemeAmount, actualPairAmount, liquidity);
        emit ReservesUpdated(reserveMeme, reservePair);
        
        return liquidity;
    }
    
    /**
     * @dev 移除流动性
     * @param liquidityTokens 要移除的流动性代币数量
     * @return memeAmount 返回的 Meme 代币数量
     * @return pairAmount 返回的配对代币数量
     */
    function removeLiquidity(uint256 liquidityTokens) 
        external 
        whenNotPaused
        nonReentrant 
        returns (uint256 memeAmount, uint256 pairAmount) 
    {
        require(liquidityTokens > 0, "Liquidity tokens must be greater than 0");
        require(
            liquidityBalances[msg.sender] >= liquidityTokens,
            "Insufficient liquidity balance"
        );
        
        // 计算移除后剩余的 LP token 数量
        uint256 remainingLiquidity = totalLiquiditySupply - liquidityTokens;
        
        // 如果移除后剩余的 LP token 小于等于最小流动性要求，说明这是最后一次真正的移除
        // 需要计算 MINIMUM_LIQUIDITY 对应的储备量并永久锁定
        if (remainingLiquidity <= MINIMUM_LIQUIDITY) {
            // 最后一次移除，计算 MINIMUM_LIQUIDITY 对应的储备量（永久锁定）
            uint256 lockedMemeAmount = (MINIMUM_LIQUIDITY * reserveMeme) / totalLiquiditySupply;
            uint256 lockedPairAmount = (MINIMUM_LIQUIDITY * reservePair) / totalLiquiditySupply;
            
            // 返回所有储备量减去永久锁定的部分，避免精度损失
            memeAmount = reserveMeme - lockedMemeAmount;
            pairAmount = reservePair - lockedPairAmount;
            
            require(memeAmount > 0 && pairAmount > 0, "Insufficient liquidity after lock");
            
            // 更新储备量（保留 MINIMUM_LIQUIDITY 对应的储备量）
            reserveMeme = lockedMemeAmount;
            reservePair = lockedPairAmount;
            
            // 更新流动性代币
            liquidityBalances[msg.sender] -= liquidityTokens;
            totalLiquiditySupply -= liquidityTokens;
        } else {
            // 正常情况：根据流动性代币的比例计算应返回的代币数量
            memeAmount = (liquidityTokens * reserveMeme) / totalLiquiditySupply;
            pairAmount = (liquidityTokens * reservePair) / totalLiquiditySupply;
            
            require(memeAmount > 0 && pairAmount > 0, "Insufficient liquidity");
            
            // 更新储备量
            reserveMeme -= memeAmount;
            reservePair -= pairAmount;
            
            // 更新流动性代币
            liquidityBalances[msg.sender] -= liquidityTokens;
            totalLiquiditySupply -= liquidityTokens;
        }
        
        // 转移代币给用户
        memeToken.safeTransfer(msg.sender, memeAmount);
        // 发送 ETH 给用户
        (bool success, ) = payable(msg.sender).call{value: pairAmount}("");
        require(success, "ETH transfer failed");
        
        emit LiquidityRemoved(msg.sender, memeAmount, pairAmount, liquidityTokens);
        emit ReservesUpdated(reserveMeme, reservePair);
        
        return (memeAmount, pairAmount);
    }
    
    /**
     * @dev 使用 ETH 购买 Meme 代币
     * @param minMemeOut 预期获得的最少 Meme 代币数量（滑点保护）
     * @return memeAmountOut 实际获得的 Meme 代币数量
     * @notice 通过 msg.value 接收 ETH，不需要传入 pairAmountIn 参数
     */
    function swapEthForMeme(uint256 minMemeOut) 
        external 
        payable
        whenNotPaused
        nonReentrant 
        returns (uint256 memeAmountOut) 
    {
        uint256 pairAmountIn = msg.value;
        require(pairAmountIn > 0, "Input amount must be greater than 0");
        require(reserveMeme > 0 && reservePair > 0, "Insufficient reserves");
        
        // ETH 已通过 msg.value 自动转入合约
        
        // 计算输出数量（使用恒定乘积公式：x * y = k）
        // 考虑交易手续费：pairAmountIn * (1 - fee) = amountAfterFee
        uint256 amountAfterFee = pairAmountIn * (10000 - tradingFee) / 10000;
        uint256 newReservePair = reservePair + amountAfterFee;
        
        // 使用公式：memeAmountOut = (reserveMeme * amountAfterFee) / (reservePair + amountAfterFee)
        memeAmountOut = (reserveMeme * amountAfterFee) / newReservePair;
        
        require(memeAmountOut >= minMemeOut, "Insufficient output amount");
        require(memeAmountOut < reserveMeme, "Insufficient liquidity");
        
        // 更新储备量
        reservePair = newReservePair;
        reserveMeme -= memeAmountOut;
        
        // 转移 Meme 代币给用户
        memeToken.safeTransfer(msg.sender, memeAmountOut);
        
        emit TokenSwapped(msg.sender, address(0), address(memeToken), pairAmountIn, memeAmountOut);
        emit ReservesUpdated(reserveMeme, reservePair);
        
        return memeAmountOut;
    }
    
    /**
     * @dev 使用 Meme 代币购买 ETH
     * @param memeAmountIn 输入的 Meme 代币数量
     * @param minEthOut 预期获得的最少 ETH 数量（滑点保护）
     * @return ethAmountOut 实际获得的 ETH 数量
     */
    function swapMemeForEth(uint256 memeAmountIn, uint256 minEthOut) 
        external 
        whenNotPaused
        nonReentrant 
        returns (uint256 ethAmountOut) 
    {
        require(memeAmountIn > 0, "Input amount must be greater than 0");
        require(reserveMeme > 0 && reservePair > 0, "Insufficient reserves");
        
        // 转移输入的 Meme 代币到池子
        memeToken.safeTransferFrom(msg.sender, address(this), memeAmountIn);
        
        // 计算输出数量（使用恒定乘积公式：x * y = k）
        // 考虑交易手续费：memeAmountIn * (1 - fee) = amountAfterFee
        uint256 amountAfterFee = memeAmountIn * (10000 - tradingFee) / 10000;
        uint256 newReserveMeme = reserveMeme + amountAfterFee;
        
        // 使用公式：ethAmountOut = (reservePair * amountAfterFee) / (reserveMeme + amountAfterFee)
        ethAmountOut = (reservePair * amountAfterFee) / newReserveMeme;
        
        require(ethAmountOut >= minEthOut, "Insufficient output amount");
        require(ethAmountOut < reservePair, "Insufficient liquidity");
        
        // 更新储备量
        reserveMeme = newReserveMeme;
        reservePair -= ethAmountOut;
        
        // 发送 ETH 给用户
        (bool success, ) = payable(msg.sender).call{value: ethAmountOut}("");
        require(success, "ETH transfer failed");
        
        emit TokenSwapped(msg.sender, address(memeToken), address(0), memeAmountIn, ethAmountOut);
        emit ReservesUpdated(reserveMeme, reservePair);
        
        return ethAmountOut;
    }
    
    // ============ 管理员函数 ============
    
    /**
     * @dev 暂停合约（仅限所有者）
     * @notice 暂停后，所有核心功能（添加/移除流动性、交易）将被禁止
     * @notice 合约初始状态为暂停，需要调用 unpause() 来启用
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev 取消暂停合约（仅限所有者）
     * @notice 恢复合约的正常运行状态
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev 设置交易手续费率（仅限所有者）
     * @param _tradingFee 新的费率（以基点为单位，10000 = 100%）
     * @notice 例如：30 = 0.3%, 100 = 1%
     * @notice 费率上限为 1000 (10%)，防止设置过高费率影响用户体验
     */
    function setTradingFee(uint256 _tradingFee) external onlyOwner {
        require(_tradingFee <= 10000, "Fee cannot exceed 100%");
        require(_tradingFee <= 1000, "Fee should not exceed 10% for safety");
        
        uint256 oldFee = tradingFee;
        tradingFee = _tradingFee;
        
        emit TradingFeeChanged(oldFee, _tradingFee);
    }
    
    
    // ============ 查询函数 ============
    
    /**
     * @dev 获取池子的完整状态信息
     * @return _reserveMeme Meme 代币储备量
     * @return _reservePair ETH 储备量（wei）
     * @return _totalLiquiditySupply 总流动性代币供应量
     * @return _tradingFee 当前交易手续费率（基点）
     * @return _price 当前价格（ETH/Meme代币，保留18位小数）
     * @return _isPaused 是否暂停
     */
    function getPoolInfo() 
        external 
        view 
        returns (
            uint256 _reserveMeme,
            uint256 _reservePair,
            uint256 _totalLiquiditySupply,
            uint256 _tradingFee,
            uint256 _price,
            bool _isPaused
        ) 
    {
        _reserveMeme = reserveMeme;
        _reservePair = reservePair;
        _totalLiquiditySupply = totalLiquiditySupply;
        _tradingFee = tradingFee;
        _price = reserveMeme == 0 ? 0 : (reservePair * 1e18) / reserveMeme;
        _isPaused = paused();
        return (_reserveMeme, _reservePair, _totalLiquiditySupply, _tradingFee, _price, _isPaused);
    }
    
    /**
     * @dev 获取储备量信息（快捷查询）
     * @return _reserveMeme Meme 代币储备量
     * @return _reservePair ETH 储备量（wei）
     */
    function getReserves() external view returns (uint256 _reserveMeme, uint256 _reservePair) {
        return (reserveMeme, reservePair);
    }
    
    /**
     * @dev 计算添加流动性后应得的 LP token 数量
     * @param memeAmount 要添加的 Meme 代币数量
     * @param pairAmount 要添加的 ETH 数量（wei）
     * @return 预期的流动性代币数量
     */
    function calculateLiquidityTokens(uint256 memeAmount, uint256 pairAmount) 
        external 
        view 
        returns (uint256) 
    {
        if (totalLiquiditySupply == 0) {
            return Math.sqrt(memeAmount * pairAmount) - MINIMUM_LIQUIDITY;
        }
        
        uint256 liquidityFromMeme = (memeAmount * totalLiquiditySupply) / reserveMeme;
        uint256 liquidityFromPair = (pairAmount * totalLiquiditySupply) / reservePair;
        
        return liquidityFromMeme < liquidityFromPair ? liquidityFromMeme : liquidityFromPair;
    }
    
    /**
     * @dev 计算移除流动性后应得的代币数量
     * @param liquidityTokens 要移除的流动性代币数量
     * @return memeAmount 应得的 Meme 代币数量
     * @return pairAmount 应得的 ETH 数量（wei）
     */
    function calculateRemoveLiquidity(uint256 liquidityTokens) 
        external 
        view 
        returns (uint256 memeAmount, uint256 pairAmount) 
    {
        if (totalLiquiditySupply == 0) return (0, 0);
        memeAmount = (liquidityTokens * reserveMeme) / totalLiquiditySupply;
        pairAmount = (liquidityTokens * reservePair) / totalLiquiditySupply;
        return (memeAmount, pairAmount);
    }
    
    /**
     * @dev 计算交换输出的代币数量及价格影响
     * @param tokenIn 输入代币地址（address(0) 表示 ETH，否则为 Meme 代币地址）
     * @param amountIn 输入代币数量
     * @return amountOut 输出代币数量
     * @return priceImpact 价格影响（以基点为单位，表示交易对价格的冲击程度）
     */
    function getAmountOut(address tokenIn, uint256 amountIn) 
        external 
        view 
        returns (uint256 amountOut, uint256 priceImpact) 
    {
        require(tokenIn == address(memeToken) || tokenIn == address(0), "Invalid token");
        require(reserveMeme > 0 && reservePair > 0, "Insufficient reserves");
        
        uint256 amountAfterFee = amountIn * (10000 - tradingFee) / 10000;
        
        if (tokenIn == address(memeToken)) {
            // 用 Meme 代币换取 ETH
            uint256 newReserveMeme = reserveMeme + amountAfterFee;
            amountOut = (reservePair * amountAfterFee) / newReserveMeme;
            // 计算价格影响：(amountAfterFee / reserveMeme) * 10000
            priceImpact = (amountAfterFee * 10000) / reserveMeme;
        } else {
            // 用 ETH 换取 Meme 代币（tokenIn == address(0)）
            uint256 newReservePair = reservePair + amountAfterFee;
            amountOut = (reserveMeme * amountAfterFee) / newReservePair;
            // 计算价格影响：(amountAfterFee / reservePair) * 10000
            priceImpact = (amountAfterFee * 10000) / reservePair;
        }
        
        return (amountOut, priceImpact);
    }
    
    /**
     * @dev 获取用户的流动性信息
     * @param account 用户地址
     * @return liquidityBalance 用户的流动性代币余额
     * @return memeValue 对应的 Meme 代币数量
     * @return pairValue 对应的 ETH 数量（wei）
     * @return share 份额占比（以基点为单位，10000 = 100%）
     */
    function getUserLiquidityInfo(address account) 
        external 
        view 
        returns (
            uint256 liquidityBalance,
            uint256 memeValue,
            uint256 pairValue,
            uint256 share
        ) 
    {
        liquidityBalance = liquidityBalances[account];
        
        if (totalLiquiditySupply == 0) {
            return (liquidityBalance, 0, 0, 0);
        }
        
        memeValue = (liquidityBalance * reserveMeme) / totalLiquiditySupply;
        pairValue = (liquidityBalance * reservePair) / totalLiquiditySupply;
        share = (liquidityBalance * 10000) / totalLiquiditySupply;
        
        return (liquidityBalance, memeValue, pairValue, share);
    }
}

