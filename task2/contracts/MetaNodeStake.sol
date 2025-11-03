// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract MetaNodeStake is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;


    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");

    uint256 public constant ETH_PID = 0;
    
    struct Pool {
        // 质押代币地址
        address stTokenAddress;
        // 池权重
        uint256 poolWeight;
        // 池的 MetaNode 分配发生的最后一个区块号
        uint256 lastRewardBlock;
        // 池的每个质押代币累积的 MetaNode，每个质押代币累积的 RCC 数量
        uint256 accMetaNodePerST;
        // 质押代币数量
        uint256 stTokenAmount;
        // 最小质押数量
        uint256 minDepositAmount;
        // 提取锁定区块数
        uint256 unstakeLockedBlocks;
    }

    struct UnstakeRequest {
        // 请求提取数量
        uint256 amount;
        // 请求提取数量可以释放的区块数
        uint256 unlockBlocks;
    }

    struct User {
        // 用户提供的质押代币数量
        uint256 stAmount;
        // 已完成的分配给用户的 MetaNode
        uint256 finishedMetaNode;
        // 待领取的 MetaNode
        uint256 pendingMetaNode;
        // 提取请求列表
        UnstakeRequest[] requests;
    }


    // MetaNodeStake 开始的第一个区块
    uint256 public startBlock;
    // MetaNodeStake 结束的第一个区块
    uint256 public endBlock;
    // 每个区块的 MetaNode 代币奖励
    uint256 public MetaNodePerBlock;

    // 暂停存款功能（紧急安全机制）
    bool public depositPaused;
    // 暂停提取功能
    bool public withdrawPaused;
    // 暂停领取功能
    bool public claimPaused;

    // MetaNode 代币
    IERC20 public MetaNode;

    // 总池权重 / 所有池权重的总和
    uint256 public totalPoolWeight;
    Pool[] public pool;

    // 池 id => 用户地址 => 用户信息
    mapping (uint256 => mapping (address => User)) public user;


    event SetMetaNode(IERC20 indexed MetaNode); // 设置 MetaNode 代币

    event PauseDeposit(); // 暂停存款

    event UnpauseDeposit(); // 取消暂停存款

    event PauseWithdraw(); // 暂停提取

    event UnpauseWithdraw(); // 取消暂停提取

    event PauseClaim(); // 暂停领取

    event UnpauseClaim(); // 取消暂停领取

    event SetStartBlock(uint256 indexed startBlock); // 设置开始区块

    event SetEndBlock(uint256 indexed endBlock); // 设置结束区块

    event SetMetaNodePerBlock(uint256 indexed MetaNodePerBlock); // 设置每区块 MetaNode 数量

    event AddPool(address indexed stTokenAddress, uint256 indexed poolWeight, uint256 indexed lastRewardBlock, uint256 minDepositAmount, uint256 unstakeLockedBlocks); // 添加池

    event UpdatePoolInfo(uint256 indexed poolId, uint256 indexed minDepositAmount, uint256 indexed unstakeLockedBlocks); // 更新池信息

    event SetPoolWeight(uint256 indexed poolId, uint256 indexed poolWeight, uint256 totalPoolWeight); // 设置池权重

    event UpdatePool(uint256 indexed poolId, uint256 indexed lastRewardBlock, uint256 totalMetaNode); // 更新池

    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount); // 存款

    event RequestUnstake(address indexed user, uint256 indexed poolId, uint256 amount); // 请求解质押

    event Withdraw(address indexed user, uint256 indexed poolId, uint256 amount, uint256 indexed blockNumber); // 提取

    event Claim(address indexed user, uint256 indexed poolId, uint256 MetaNodeReward); // 领取奖励


    modifier checkPid(uint256 _pid) {
        require(_pid < pool.length, "invalid pid"); // 检查池 ID 是否有效
        _;
    }

    modifier whenNotClaimPaused() {
        require(!claimPaused, "claim is paused"); // 检查领取功能是否未暂停
        _;
    }

    modifier whenNotDepositPaused() {
        require(!depositPaused, "deposit is paused"); // 检查存款功能是否未暂停
        _;
    }

    modifier whenNotWithdrawPaused() {
        require(!withdrawPaused, "withdraw is paused"); // 检查提取功能是否未暂停
        _;
    }

    /**
     * @notice 设置 MetaNode 代币地址。在部署时设置基本信息。
     */
    function initialize(
        IERC20 _MetaNode,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _MetaNodePerBlock
    ) public initializer {
        require(_startBlock <= _endBlock && _MetaNodePerBlock > 0, "invalid parameters"); // 检查参数有效性

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        setMetaNode(_MetaNode);

        startBlock = _startBlock;
        endBlock = _endBlock;
        MetaNodePerBlock = _MetaNodePerBlock;

    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADE_ROLE)
        override
    {

    }

    /**
     * @notice 设置 MetaNode 代币地址。只能由管理员调用
     */
    function setMetaNode(IERC20 _MetaNode) public onlyRole(ADMIN_ROLE) {
        MetaNode = _MetaNode;

        emit SetMetaNode(MetaNode);
    }

    /**
     * @notice 暂停存款。只能由管理员调用。用于紧急情况下的安全控制。
     */
    function pauseDeposit() public onlyRole(ADMIN_ROLE) {
        require(!depositPaused, "deposit has been already paused");

        depositPaused = true;

        emit PauseDeposit();
    }

    /**
     * @notice 取消暂停存款。只能由管理员调用。
     */
    function unpauseDeposit() public onlyRole(ADMIN_ROLE) {
        require(depositPaused, "deposit has been already unpaused");

        depositPaused = false;

        emit UnpauseDeposit();
    }

    /**
     * @notice 暂停提取。只能由管理员调用。
     */
    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(!withdrawPaused, "withdraw has been already paused");

        withdrawPaused = true;

        emit PauseWithdraw();
    }

    /**
     * @notice 取消暂停提取。只能由管理员调用。
     */
    function unpauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(withdrawPaused, "withdraw has been already unpaused");

        withdrawPaused = false;

        emit UnpauseWithdraw();
    }

    /**
     * @notice 暂停领取。只能由管理员调用。
     */
    function pauseClaim() public onlyRole(ADMIN_ROLE) {
        require(!claimPaused, "claim has been already paused");

        claimPaused = true;

        emit PauseClaim();
    }

    /**
     * @notice 取消暂停领取。只能由管理员调用。
     */
    function unpauseClaim() public onlyRole(ADMIN_ROLE) {
        require(claimPaused, "claim has been already unpaused");

        claimPaused = false;

        emit UnpauseClaim();
    }

    /**
     * @notice 更新质押开始区块。只能由管理员调用。
     */
    function setStartBlock(uint256 _startBlock) public onlyRole(ADMIN_ROLE) {
        require(_startBlock <= endBlock, "start block must be smaller than end block"); // 开始区块必须小于结束区块

        startBlock = _startBlock;

        emit SetStartBlock(_startBlock);
    }

    /**
     * @notice 更新质押结束区块。只能由管理员调用。
     */
    function setEndBlock(uint256 _endBlock) public onlyRole(ADMIN_ROLE) {
        require(startBlock <= _endBlock, "start block must be smaller than end block"); // 开始区块必须小于结束区块

        endBlock = _endBlock;

        emit SetEndBlock(_endBlock);
    }

    /**
     * @notice 更新每个区块的 MetaNode 奖励数量。只能由管理员调用。
     */
    function setMetaNodePerBlock(uint256 _MetaNodePerBlock) public onlyRole(ADMIN_ROLE) {
        require(_MetaNodePerBlock > 0, "invalid parameter"); // 参数无效

        MetaNodePerBlock = _MetaNodePerBlock;

        emit SetMetaNodePerBlock(_MetaNodePerBlock);
    }

    /**
     * @notice 向池中添加新的质押。只能由管理员调用
     * 不要多次添加相同的质押代币。如果这样做，MetaNode 奖励将会混乱
     */
    function addPool(address _stTokenAddress, uint256 _poolWeight, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks,  bool _withUpdate) public onlyRole(ADMIN_ROLE) {
        // 默认第一个池为 ETH 池，所以第一个池必须使用 stTokenAddress = address(0x0) 添加
        if (pool.length > 0) {
            require(_stTokenAddress != address(0x0), "invalid staking token address");
        } else {
            require(_stTokenAddress == address(0x0), "invalid staking token address");
        }
        // 允许最小存款数量等于 0
        //require(_minDepositAmount > 0, "invalid min deposit amount");
        require(_unstakeLockedBlocks > 0, "invalid withdraw locked blocks");
        require(block.number < endBlock, "Already ended");

        if (_withUpdate) {
            massUpdatePools();
        }

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalPoolWeight = totalPoolWeight + _poolWeight;

        pool.push(Pool({
            stTokenAddress: _stTokenAddress,
            poolWeight: _poolWeight,
            lastRewardBlock: lastRewardBlock,
            accMetaNodePerST: 0,
            stTokenAmount: 0,
            minDepositAmount: _minDepositAmount,
            unstakeLockedBlocks: _unstakeLockedBlocks
        }));

        emit AddPool(_stTokenAddress, _poolWeight, lastRewardBlock, _minDepositAmount, _unstakeLockedBlocks);
    }

    /**
     * @notice 更新给定池的信息（minDepositAmount 和 unstakeLockedBlocks）。只能由管理员调用。
     */
    function updatePool(uint256 _pid, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        pool[_pid].minDepositAmount = _minDepositAmount;
        pool[_pid].unstakeLockedBlocks = _unstakeLockedBlocks;

        emit UpdatePoolInfo(_pid, _minDepositAmount, _unstakeLockedBlocks);
    }

    /**
     * @notice 更新给定池的权重。只能由管理员调用。
     */
    function setPoolWeight(uint256 _pid, uint256 _poolWeight, bool _withUpdate) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        require(_poolWeight > 0, "invalid pool weight"); // 池权重无效
        
        if (_withUpdate) {
            massUpdatePools();
        }

        totalPoolWeight = totalPoolWeight - pool[_pid].poolWeight + _poolWeight;
        pool[_pid].poolWeight = _poolWeight;

        emit SetPoolWeight(_pid, _poolWeight, totalPoolWeight);
    }

    /**
     * @notice 获取池的长度/数量
     */
    function poolLength() external view returns(uint256) {
        return pool.length;
    }

    /**
     * @notice 返回给定 _from 到 _to 区块的奖励乘数。[_from, _to)
     *
     * @param _from    起始区块号（包含）
     * @param _to      结束区块号（不包含）
     */
    function getMultiplier(uint256 _from, uint256 _to) public view returns(uint256 multiplier) {
        require(_from <= _to, "invalid block"); // 区块号无效
        if (_from < startBlock) {_from = startBlock;} // 调整起始区块
        if (_to > endBlock) {_to = endBlock;} // 调整结束区块
        require(_from <= _to, "end block must be greater than start block"); // 结束区块必须大于开始区块
        bool success;
        (success, multiplier) = (_to - _from).tryMul(MetaNodePerBlock);
        require(success, "multiplier overflow"); // 乘数溢出
    }

    /**
     * @notice 获取用户在池中的待分配 MetaNode 数量
     */
    function pendingMetaNode(uint256 _pid, address _user) external checkPid(_pid) view returns(uint256) {
        return pendingMetaNodeByBlockNumber(_pid, _user, block.number);
    }

    /**
     * @notice 通过区块号获取用户在池中的待分配 MetaNode 数量
     */
    function pendingMetaNodeByBlockNumber(uint256 _pid, address _user, uint256 _blockNumber) public checkPid(_pid) view returns(uint256) {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][_user];
        uint256 accMetaNodePerST = pool_.accMetaNodePerST;
        uint256 stSupply = pool_.stTokenAmount;

        if (_blockNumber > pool_.lastRewardBlock && stSupply != 0) {
            uint256 multiplier = getMultiplier(pool_.lastRewardBlock, _blockNumber);
            uint256 MetaNodeForPool = multiplier * pool_.poolWeight / totalPoolWeight;
            accMetaNodePerST = accMetaNodePerST + MetaNodeForPool * (1 ether) / stSupply;
        }

        return user_.stAmount * accMetaNodePerST / (1 ether) - user_.finishedMetaNode + user_.pendingMetaNode;
    }

    /**
     * @notice 获取用户的质押数量
     */
    function stakingBalance(uint256 _pid, address _user) external checkPid(_pid) view returns(uint256) {
        return user[_pid][_user].stAmount;
    }

    /**
     * @notice 获取提取数量信息，包括锁定的解质押数量和已解锁的解质押数量
     */
    function withdrawAmount(uint256 _pid, address _user) public checkPid(_pid) view returns(uint256 requestAmount, uint256 pendingWithdrawAmount) {
        User storage user_ = user[_pid][_user];

        for (uint256 i = 0; i < user_.requests.length; i++) {
            if (user_.requests[i].unlockBlocks <= block.number) {
                pendingWithdrawAmount = pendingWithdrawAmount + user_.requests[i].amount;
            }
            requestAmount = requestAmount + user_.requests[i].amount;
        }
    }

    /**
     * @notice 更新给定池的奖励变量以保持最新。
     */
    function updatePool(uint256 _pid) public checkPid(_pid) {
        Pool storage pool_ = pool[_pid];

        if (block.number <= pool_.lastRewardBlock) {
            return;
        }

        (bool success1, uint256 totalMetaNode) = getMultiplier(pool_.lastRewardBlock, block.number).tryMul(pool_.poolWeight);
        require(success1, "overflow");

        (success1, totalMetaNode) = totalMetaNode.tryDiv(totalPoolWeight);
        require(success1, "overflow");

        uint256 stSupply = pool_.stTokenAmount;
        if (stSupply > 0) {
            (bool success2, uint256 totalMetaNode_) = totalMetaNode.tryMul(1 ether);
            require(success2, "overflow");

            (success2, totalMetaNode_) = totalMetaNode_.tryDiv(stSupply);
            require(success2, "overflow");

            (bool success3, uint256 accMetaNodePerST) = pool_.accMetaNodePerST.tryAdd(totalMetaNode_);
            require(success3, "overflow");
            pool_.accMetaNodePerST = accMetaNodePerST;
        }

        pool_.lastRewardBlock = block.number;

        emit UpdatePool(_pid, pool_.lastRewardBlock, totalMetaNode);
    }

    /**
     * @notice 更新所有池的奖励变量。注意 gas 消耗！
     */
    function massUpdatePools() public {
        uint256 length = pool.length;
        for (uint256 pid = 0; pid < length; pid++) {
            updatePool(pid);
        }
    }

    /**
     * @notice 存入质押 ETH 以获得 MetaNode 奖励
     */
    function depositETH() public whenNotDepositPaused() payable {
        Pool storage pool_ = pool[ETH_PID];
        require(pool_.stTokenAddress == address(0x0), "invalid staking token address"); // 质押代币地址无效

        uint256 _amount = msg.value;
        require(_amount >= pool_.minDepositAmount, "deposit amount is too small"); // 存款数量太小

        _deposit(ETH_PID, _amount);
    }

    /**
     * @notice 存入质押代币以获得 MetaNode 奖励
     * 在存入之前，用户需要授权此合约能够花费或转移其质押代币
     *
     * @param _pid       要存入的池的 ID
     * @param _amount    要存入的质押代币数量
     */
    function deposit(uint256 _pid, uint256 _amount) public whenNotDepositPaused() checkPid(_pid) {
        require(_pid != 0, "deposit not support ETH staking"); // 存款不支持 ETH 质押
        Pool storage pool_ = pool[_pid];
        require(_amount >= pool_.minDepositAmount, "deposit amount is too small"); // 存款数量太小

        if(_amount > 0) {
            IERC20(pool_.stTokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
        }

        _deposit(_pid, _amount);
    }

    /**
     * @notice 解质押代币
     *
     * @param _pid       要从中提取的池的 ID
     * @param _amount    要提取的质押代币数量
     */
    function unstake(uint256 _pid, uint256 _amount) public checkPid(_pid) whenNotWithdrawPaused() {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        require(user_.stAmount >= _amount, "Not enough staking token balance"); // 质押代币余额不足

        updatePool(_pid);

        uint256 pendingMetaNode_ = user_.stAmount * pool_.accMetaNodePerST / (1 ether) - user_.finishedMetaNode;

        if(pendingMetaNode_ > 0) {
            user_.pendingMetaNode = user_.pendingMetaNode + pendingMetaNode_;
        }

        if(_amount > 0) {
            user_.stAmount = user_.stAmount - _amount;
            user_.requests.push(UnstakeRequest({
                amount: _amount,
                unlockBlocks: block.number + pool_.unstakeLockedBlocks
            }));
        }

        pool_.stTokenAmount = pool_.stTokenAmount - _amount;
        user_.finishedMetaNode = user_.stAmount * pool_.accMetaNodePerST / (1 ether);

        emit RequestUnstake(msg.sender, _pid, _amount);
    }

    /**
     * @notice 提取已解锁的解质押数量
     *
     * @param _pid       要从中提取的池的 ID
     */
    function withdraw(uint256 _pid) public checkPid(_pid) whenNotWithdrawPaused() {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        uint256 pendingWithdraw_;
        uint256 popNum_;
        for (uint256 i = 0; i < user_.requests.length; i++) {
            if (user_.requests[i].unlockBlocks > block.number) {
                break;
            }
            pendingWithdraw_ = pendingWithdraw_ + user_.requests[i].amount;
            popNum_++;
        }

        for (uint256 i = 0; i < user_.requests.length - popNum_; i++) {
            user_.requests[i] = user_.requests[i + popNum_];
        }

        for (uint256 i = 0; i < popNum_; i++) {
            user_.requests.pop();
        }

        if (pendingWithdraw_ > 0) {
            if (pool_.stTokenAddress == address(0x0)) {
                _safeETHTransfer(msg.sender, pendingWithdraw_);
            } else {
                IERC20(pool_.stTokenAddress).safeTransfer(msg.sender, pendingWithdraw_);
            }
        }

        emit Withdraw(msg.sender, _pid, pendingWithdraw_, block.number);
    }

    /**
     * @notice 领取 MetaNode 代币奖励
     *
     * @param _pid       要从中领取的池的 ID
     */
    function claim(uint256 _pid) public checkPid(_pid) whenNotClaimPaused() {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        updatePool(_pid);

        uint256 pendingMetaNode_ = user_.stAmount * pool_.accMetaNodePerST / (1 ether) - user_.finishedMetaNode + user_.pendingMetaNode;

        if(pendingMetaNode_ > 0) {
            user_.pendingMetaNode = 0;
            _safeMetaNodeTransfer(msg.sender, pendingMetaNode_);
        }

        user_.finishedMetaNode = user_.stAmount * pool_.accMetaNodePerST / (1 ether);

        emit Claim(msg.sender, _pid, pendingMetaNode_);
    }

    /**
     * @notice 存入质押代币以获得 MetaNode 奖励
     *
     * @param _pid       要存入的池的 ID
     * @param _amount    要存入的质押代币数量
     */
    function _deposit(uint256 _pid, uint256 _amount) internal {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        updatePool(_pid);

        if (user_.stAmount > 0) {
            // uint256 accST = user_.stAmount.mulDiv(pool_.accMetaNodePerST, 1 ether);
            (bool success1, uint256 accST) = user_.stAmount.tryMul(pool_.accMetaNodePerST);
            require(success1, "user stAmount mul accMetaNodePerST overflow");
            (success1, accST) = accST.tryDiv(1 ether);
            require(success1, "accST div 1 ether overflow");
            
            (bool success2, uint256 pendingMetaNode_) = accST.trySub(user_.finishedMetaNode);
            require(success2, "accST sub finishedMetaNode overflow");

            if(pendingMetaNode_ > 0) {
                (bool success3, uint256 _pendingMetaNode) = user_.pendingMetaNode.tryAdd(pendingMetaNode_);
                require(success3, "user pendingMetaNode overflow");
                user_.pendingMetaNode = _pendingMetaNode;
            }
        }

        if(_amount > 0) {
            (bool success4, uint256 stAmount) = user_.stAmount.tryAdd(_amount);
            require(success4, "user stAmount overflow");
            user_.stAmount = stAmount;
        }

        (bool success5, uint256 stTokenAmount) = pool_.stTokenAmount.tryAdd(_amount);
        require(success5, "pool stTokenAmount overflow");
        pool_.stTokenAmount = stTokenAmount;

        // user_.finishedMetaNode = user_.stAmount.mulDiv(pool_.accMetaNodePerST, 1 ether);
        (bool success6, uint256 finishedMetaNode) = user_.stAmount.tryMul(pool_.accMetaNodePerST);
        require(success6, "user stAmount mul accMetaNodePerST overflow");

        (success6, finishedMetaNode) = finishedMetaNode.tryDiv(1 ether);
        require(success6, "finishedMetaNode div 1 ether overflow");

        user_.finishedMetaNode = finishedMetaNode;

        emit Deposit(msg.sender, _pid, _amount);
    }

    /**
     * @notice 安全的 MetaNode 转账功能，以防舍入错误导致池中没有足够的 MetaNode
     *
     * @param _to        接收转账 MetaNode 的地址
     * @param _amount    要转账的 MetaNode 数量
     */
    function _safeMetaNodeTransfer(address _to, uint256 _amount) internal {
        uint256 MetaNodeBal = MetaNode.balanceOf(address(this));

        if (_amount > MetaNodeBal) {
            MetaNode.transfer(_to, MetaNodeBal);
        } else {
            MetaNode.transfer(_to, _amount);
        }
    }

    /**
     * @notice 安全的 ETH 转账功能
     *
     * @param _to        接收转账 ETH 的地址
     * @param _amount    要转账的 ETH 数量
     */
    function _safeETHTransfer(address _to, uint256 _amount) internal {
        Address.sendValue(payable(_to), _amount);
    }
}