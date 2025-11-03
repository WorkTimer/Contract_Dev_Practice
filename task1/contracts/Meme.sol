// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Meme Token
 * @dev SHIB 风格的 Meme 代币合约
 * @notice 实现了交易税机制、交易限制、流动性池集成功能和代币销毁功能
 */
contract Meme is ERC20, ERC20Burnable, Ownable, ReentrancyGuard, Pausable {
    // ============ 状态变量 ============
    
    /**
     * @dev 买入税率（以基点为单位，10000 = 100%）
     * @notice 例如：100 = 1%，500 = 5%
     * @notice 从流动性池买入时收取
     */
    uint256 public buyTaxRate; // 基点 (10000 = 100%)
    
    /**
     * @dev 卖出税率（以基点为单位，10000 = 100%）
     * @notice 例如：100 = 1%，500 = 5%
     * @notice 向流动性池卖出时收取
     */
    uint256 public sellTaxRate; // 基点 (10000 = 100%)
    
    /**
     * @dev 税费接收地址（用于接收交易税的地址）
     */
    address public taxRecipient;
    
    /**
     * @dev 单笔交易最大额度（以代币数量计算）
     * @notice 用于防止大额交易操纵市场
     */
    uint256 public maxTransactionAmount;
    
    /**
     * @dev 每日交易次数限制
     * @notice 每个地址每日最多可执行的交易次数
     */
    uint256 public dailyTransactionLimit;
    
    /**
     * @dev 不受交易税限制的地址映射
     * @notice 流动性池地址和税费接收地址等应被豁免
     */
    mapping(address => bool) public exemptFromTax;
    
    /**
     * @dev 不受交易限制约束的地址映射
     * @notice 流动性池和 DEX 路由器地址通常需要豁免交易限制
     */
    mapping(address => bool) public exemptFromLimits;
    
    /**
     * @dev 记录每个地址每日的交易次数
     * @notice 使用日期作为键，地址作为嵌套键，值当日交易次数
     */
    mapping(uint256 => mapping(address => uint256)) public dailyTransactionCount;
    
    /**
     * @dev 最后一次重置每日计数的日期
     */
    mapping(address => uint256) public lastTransactionDate;
    
    /**
     * @dev 流动性池地址
     */
    address public liquidityPool;
    
    /**
     * @dev 锁定时间映射，用于交易时间限制（可选功能）
     */
    mapping(address => uint256) public lockedUntil;
    
    // ============ 事件 ============
    
    /**
     * @dev 当买入税率被更新时触发
     */
    event BuyTaxRateUpdated(uint256 oldRate, uint256 newRate);
    
    /**
     * @dev 当卖出税率被更新时触发
     */
    event SellTaxRateUpdated(uint256 oldRate, uint256 newRate);
    
    /**
     * @dev 当税费接收地址被更新时触发
     */
    event TaxRecipientUpdated(address oldRecipient, address newRecipient);
    
    /**
     * @dev 当交易限制被更新时触发
     */
    event TransactionLimitsUpdated(uint256 maxAmount, uint256 dailyLimit);
    
    /**
     * @dev 当税费被分配时触发
     */
    event TaxCollected(address indexed recipient, uint256 amount);
    
    /**
     * @dev 当地址的税务豁免状态被更新时触发
     */
    event TaxExemptionUpdated(address indexed account, bool exempt);
    
    /**
     * @dev 当地址的限制豁免状态被更新时触发
     */
    event LimitExemptionUpdated(address indexed account, bool exempt);
    
    /**
     * @dev 当流动性池地址被设置时触发
     */
    event LiquidityPoolUpdated(address indexed newPool);
    
    // ============ 构造函数 ============
    
    /**
     * @dev 初始化 Meme 代币合约
     * @param name 代币名称
     * @param symbol 代币符号
     * @param totalSupply 代币总供应量
     * @param _buyTaxRate 初始买入税率（基点，例如 500 = 5%）
     * @param _sellTaxRate 初始卖出税率（基点，例如 500 = 5%）
     * @param _taxRecipient 税费接收地址
     * @param _maxTransactionAmount 单笔交易最大额度
     * @param _dailyTransactionLimit 每日交易次数限制
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 _buyTaxRate,
        uint256 _sellTaxRate,
        address _taxRecipient,
        uint256 _maxTransactionAmount,
        uint256 _dailyTransactionLimit
    ) ERC20(name, symbol) Ownable(msg.sender) {
        require(_buyTaxRate <= 1000, "Buy tax rate cannot exceed 10%"); // 最多 10% 的税率
        require(_sellTaxRate <= 1000, "Sell tax rate cannot exceed 10%"); // 最多 10% 的税率
        require(_taxRecipient != address(0), "Tax recipient cannot be zero address");
        require(_maxTransactionAmount > 0, "Max transaction amount must be greater than 0");
        
        buyTaxRate = _buyTaxRate;
        sellTaxRate = _sellTaxRate;
        taxRecipient = _taxRecipient;
        maxTransactionAmount = _maxTransactionAmount;
        dailyTransactionLimit = _dailyTransactionLimit;
        
        // 默认将税费接收地址设置为不受税和限制约束
        exemptFromTax[_taxRecipient] = true;
        exemptFromLimits[_taxRecipient] = true;
        
        // 默认将合约创建者设置为不受限制约束
        exemptFromLimits[msg.sender] = true;
        exemptFromTax[msg.sender] = true;
        
        // 铸造总供应量给合约创建者
        _mint(msg.sender, totalSupply);
        
        // 初始状态下暂停交易，需要使用 unpause() 来启用
        _pause();
    }
    
    // ============ Modifier ============
    
    /**
     * @dev 检查交易是否已启用
     * @notice 如果合约处于暂停状态，只有豁免限制的地址可以交易
     */
    modifier tradingAllowed(address account) {
        // 如果合约未暂停，或者账户被豁免限制，则允许交易
        if (paused() && !exemptFromLimits[account]) {
            revert EnforcedPause();
        }
        _;
    }
    
    /**
     * @dev 检查单笔交易最大额度限制
     * @param from 发送地址
     * @param to 接收地址
     * @param amount 交易金额
     * @notice 如果发送方或接收方被豁免限制，则跳过检查
     */
    modifier checkMaxTransactionAmount(address from, address to, uint256 amount) {
        // 如果发送方或接收方被豁免限制，则跳过检查
        if (!exemptFromLimits[from] && !exemptFromLimits[to]) {
            require(
                amount <= maxTransactionAmount,
                "Transaction amount exceeds maximum allowed"
            );
        }
        _;
    }
    
    /**
     * @dev 检查每日交易次数限制
     * @param from 发送地址
     * @param to 接收地址
     * @notice 如果发送方或接收方被豁免限制，或者涉及流动性池，则跳过检查
     */
    modifier checkDailyTransactionLimit(address from, address to) {
        // 如果发送方或接收方被豁免限制，则跳过检查
        if (!exemptFromLimits[from] && !exemptFromLimits[to]) {
            uint256 today = block.timestamp / 1 days;
            
            // 检查发送方的每日交易次数限制（除非涉及流动性池）
            if (from != liquidityPool && to != liquidityPool) {
                require(
                    dailyTransactionCount[today][from] < dailyTransactionLimit,
                    "Sender has exceeded daily transaction limit"
                );
            }
            
            // 检查接收方的每日交易次数限制（除非涉及流动性池）
            if (from != liquidityPool && to != liquidityPool) {
                require(
                    dailyTransactionCount[today][to] < dailyTransactionLimit,
                    "Recipient has exceeded daily transaction limit"
                );
            }
        }
        _;
    }
    
    // ============ 核心功能函数 ============
    
    /**
     * @dev 重写转账函数，添加交易税和限制检查
     * @param to 接收地址
     * @param amount 转账金额
     * @return 是否成功
     */
    function transfer(address to, uint256 amount) 
        public 
        virtual 
        override 
        nonReentrant
        tradingAllowed(msg.sender)
        checkMaxTransactionAmount(msg.sender, to, amount)
        checkDailyTransactionLimit(msg.sender, to)
        returns (bool) 
    {
        // 应用交易税
        uint256 taxAmount = _calculateTax(msg.sender, to, amount);
        uint256 transferAmount = amount - taxAmount;
        
        // 使用内部 _transfer 方法执行转账（避免再次触发 modifier）
        _transfer(msg.sender, to, transferAmount);
        
        // 如果有税费，将其转移到税费接收地址
        if (taxAmount > 0) {
            _transfer(msg.sender, taxRecipient, taxAmount);
            emit TaxCollected(taxRecipient, taxAmount);
        }
        
        // 更新每日交易计数
        _updateDailyTransactionCount(msg.sender);
        _updateDailyTransactionCount(to);
        
        return true;
    }
    
    /**
     * @dev 重写转账授权函数，添加交易税和限制检查
     * @param from 发送地址
     * @param to 接收地址
     * @param amount 转账金额
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint256 amount) 
        public 
        virtual 
        override 
        nonReentrant
        tradingAllowed(from)
        checkMaxTransactionAmount(from, to, amount)
        checkDailyTransactionLimit(from, to)
        returns (bool) 
    {
        // 应用交易税
        uint256 taxAmount = _calculateTax(from, to, amount);
        uint256 transferAmount = amount - taxAmount;
        
        // 一次性消耗整个 amount 的授权（包括税费部分）
        _spendAllowance(from, msg.sender, amount);
        
        // 使用内部 _transfer 方法执行转账（避免再次触发 modifier）
        _transfer(from, to, transferAmount);
        
        // 如果有税费，将其转移到税费接收地址
        if (taxAmount > 0) {
            _transfer(from, taxRecipient, taxAmount);
            emit TaxCollected(taxRecipient, taxAmount);
        }
        
        // 更新每日交易计数
        _updateDailyTransactionCount(from);
        _updateDailyTransactionCount(to);
        
        return true;
    }
    
    // ============ 内部辅助函数 ============
    
    /**
     * @dev 计算交易税费
     * @param from 发送地址
     * @param to 接收地址
     * @param amount 交易金额
     * @return 税费金额
     */
    function _calculateTax(address from, address to, uint256 amount) 
        internal 
        view 
        returns (uint256) 
    {
        // 如果发送方或接收方被豁免税费，则不需要缴税
        if (exemptFromTax[from] || exemptFromTax[to]) {
            return 0;
        }
        
        // 判断交易方向并应用相应税率
        uint256 currentTaxRate;
        
        // 买入：从流动性池买入代币（from == liquidityPool）
        if (from == liquidityPool && liquidityPool != address(0)) {
            currentTaxRate = buyTaxRate;
        }
        // 卖出：向流动性池卖出代币（to == liquidityPool）
        else if (to == liquidityPool && liquidityPool != address(0)) {
            currentTaxRate = sellTaxRate;
        }
        // 普通转账（不涉及流动性池）：不收取税费
        else {
            return 0;
        }
        
        // 计算税费：金额 * 税率 / 10000
        return (amount * currentTaxRate) / 10000;
    }
    
    /**
     * @dev 更新每日交易计数
     * @param account 要更新的地址
     */
    function _updateDailyTransactionCount(address account) internal {
        uint256 today = block.timestamp / 1 days;
        
        // 如果是新的一天，重置计数
        if (lastTransactionDate[account] != today) {
            dailyTransactionCount[today][account] = 0;
            lastTransactionDate[account] = today;
        }
        
        // 增加交易计数
        dailyTransactionCount[today][account]++;
    }
    
    // ============ 管理员函数 ============
    
    /**
     * @dev 设置买入税率
     * @param newBuyTaxRate 新买入税率（基点，例如 500 = 5%）
     * @notice 只有合约所有者可以调用
     */
    function setBuyTaxRate(uint256 newBuyTaxRate) external onlyOwner {
        require(newBuyTaxRate <= 1000, "Buy tax rate cannot exceed 10%");
        uint256 oldRate = buyTaxRate;
        buyTaxRate = newBuyTaxRate;
        emit BuyTaxRateUpdated(oldRate, newBuyTaxRate);
    }
    
    /**
     * @dev 设置卖出税率
     * @param newSellTaxRate 新卖出税率（基点，例如 500 = 5%）
     * @notice 只有合约所有者可以调用
     */
    function setSellTaxRate(uint256 newSellTaxRate) external onlyOwner {
        require(newSellTaxRate <= 1000, "Sell tax rate cannot exceed 10%");
        uint256 oldRate = sellTaxRate;
        sellTaxRate = newSellTaxRate;
        emit SellTaxRateUpdated(oldRate, newSellTaxRate);
    }
    
    /**
     * @dev 设置税费接收地址
     * @param newRecipient 新的税费接收地址
     * @notice 只有合约所有者可以调用
     */
    function setTaxRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Tax recipient cannot be zero address");
        address oldRecipient = taxRecipient;
        taxRecipient = newRecipient;
        
        // 自动将新地址设置为豁免税费和限制
        exemptFromTax[newRecipient] = true;
        exemptFromLimits[newRecipient] = true;
        
        emit TaxRecipientUpdated(oldRecipient, newRecipient);
    }
    
    /**
     * @dev 设置交易限制参数
     * @param newMaxAmount 新的单笔交易最大额度
     * @param newDailyLimit 新的每日交易次数限制
     * @notice 只有合约所有者可以调用
     */
    function setTransactionLimits(uint256 newMaxAmount, uint256 newDailyLimit) external onlyOwner {
        require(newMaxAmount > 0, "Max transaction amount must be greater than 0");
        maxTransactionAmount = newMaxAmount;
        dailyTransactionLimit = newDailyLimit;
        emit TransactionLimitsUpdated(newMaxAmount, newDailyLimit);
    }
    
    /**
     * @dev 暂停交易（紧急停止功能）
     * @notice 只有合约所有者可以调用
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev 恢复交易（取消暂停）
     * @notice 只有合约所有者可以调用
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev 设置地址的税务豁免状态
     * @param account 要设置的地址
     * @param exempt 是否豁免税费
     * @notice 只有合约所有者可以调用
     */
    function setTaxExemption(address account, bool exempt) external onlyOwner {
        require(account != address(0), "Cannot set zero address");
        exemptFromTax[account] = exempt;
        emit TaxExemptionUpdated(account, exempt);
    }
    
    /**
     * @dev 设置地址的限制豁免状态
     * @param account 要设置的地址
     * @param exempt 是否豁免限制
     * @notice 只有合约所有者可以调用
     */
    function setLimitExemption(address account, bool exempt) external onlyOwner {
        require(account != address(0), "Cannot set zero address");
        exemptFromLimits[account] = exempt;
        emit LimitExemptionUpdated(account, exempt);
    }
    
    /**
     * @dev 设置流动性池地址
     * @param newPool 流动性池合约地址
     * @notice 只有合约所有者可以调用
     */
    function setLiquidityPool(address newPool) external onlyOwner {
        require(newPool != address(0), "Liquidity pool cannot be zero address");
        liquidityPool = newPool;
        
        // 自动将流动性池设置为豁免税费和限制
        exemptFromTax[newPool] = true;
        exemptFromLimits[newPool] = true;
        
        emit LiquidityPoolUpdated(newPool);
    }
    
    /**
     * @dev 批量设置税务豁免状态
     * @param accounts 地址数组
     * @param exempt 是否豁免税费
     * @notice 只有合约所有者可以调用
     */
    function batchSetTaxExemption(address[] calldata accounts, bool exempt) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] != address(0)) {
                exemptFromTax[accounts[i]] = exempt;
                emit TaxExemptionUpdated(accounts[i], exempt);
            }
        }
    }
    
    /**
     * @dev 批量设置限制豁免状态
     * @param accounts 地址数组
     * @param exempt 是否豁免限制
     * @notice 只有合约所有者可以调用
     */
    function batchSetLimitExemption(address[] calldata accounts, bool exempt) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] != address(0)) {
                exemptFromLimits[accounts[i]] = exempt;
                emit LimitExemptionUpdated(accounts[i], exempt);
            }
        }
    }
    
    // ============ 代币销毁功能 ============
    
    /**
     * @dev 销毁代币功能继承自 ERC20Burnable
     * @notice 任何持有代币的地址都可以销毁自己的代币
     * @notice 销毁操作不会受交易税、交易限制或暂停状态影响
     * @notice 销毁会永久减少代币总供应量
     * 
     * 可用函数：
     * - burn(uint256 value): 销毁调用者自己的 value 数量的代币
     * - burnFrom(address account, uint256 value): 销毁授权给你的代币（需要 account 预先授权）
     */
    
    // ============ 查询函数 ============
    
    /**
     * @dev 获取指定地址在指定日期的交易次数
     * @param account 要查询的地址
     * @param date 日期（时间戳 / 1 days）
     * @return 交易次数
     */
    function getDailyTransactionCount(address account, uint256 date) 
        external 
        view 
        returns (uint256) 
    {
        return dailyTransactionCount[date][account];
    }
    
    /**
     * @dev 获取指定地址今日的交易次数
     * @param account 要查询的地址
     * @return 今日交易次数
     */
    function getTodayTransactionCount(address account) external view returns (uint256) {
        uint256 today = block.timestamp / 1 days;
        return dailyTransactionCount[today][account];
    }
    
    /**
     * @dev 计算交易税费（不执行交易）
     * @param from 发送地址
     * @param to 接收地址
     * @param amount 交易金额
     * @return 税费金额
     * @notice 根据交易方向自动判断买入税或卖出税
     * @notice 买入（from == liquidityPool）：应用买入税率
     * @notice 卖出（to == liquidityPool）：应用卖出税率
     * @notice 普通转账（不涉及流动性池）：不收取税费
     */
    function calculateTax(address from, address to, uint256 amount) 
        external 
        view 
        returns (uint256) 
    {
        return _calculateTax(from, to, amount);
    }
}

