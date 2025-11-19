// ============================================================================
// Solana SPL Token 完整示例程序
// 功能：创建代币、铸造代币、转账代币、验证交易结果（查询代币账户余额）
// ============================================================================

use anyhow::Result;
use solana_client::nonblocking::rpc_client::RpcClient;
use solana_sdk::{
    commitment_config::CommitmentConfig,
    program_pack::Pack,
    signature::{Keypair, Signer},
    system_instruction,
    transaction::Transaction,
};
use spl_associated_token_account::{
    get_associated_token_address, instruction::create_associated_token_account,
};
use spl_token::{
    instruction::{initialize_mint2, mint_to, transfer_checked},
    state::Mint,
};

#[tokio::main]
async fn main() -> Result<()> {
    // ========================================================================
    // 第一部分：连接到 Solana 网络并获取最新区块哈希
    // ========================================================================
    
    // 创建连接到本地验证器的 RPC 客户端
    // CommitmentConfig::confirmed() 表示使用 "confirmed" 确认级别
    // 这意味着交易需要得到大多数验证者的确认
    let client = RpcClient::new_with_commitment(
        String::from("http://localhost:8899"),
        CommitmentConfig::confirmed(),
    );

    // 获取最新的区块哈希，用于防止交易重放攻击
    // 每个交易都需要一个有效的区块哈希，且有时效性
    let latest_blockhash = client.get_latest_blockhash().await?;

    // ========================================================================
    // 第二部分：创建密钥对并获取初始资金
    // ========================================================================
    
    // 生成费用支付者的密钥对
    // 在 Solana 上，每笔交易都需要支付费用（以 SOL 计价）
    // fee_payer 将支付所有交易的费用
    let fee_payer = Keypair::new();

    // 生成接收者的密钥对
    // recipient 将接收我们转账的代币
    let recipient = Keypair::new();

    // 向费用支付者空投 1 SOL (1,000,000,000 lamports)
    // lamports 是 SOL 的最小单位，1 SOL = 1,000,000,000 lamports
    // 在测试环境中，我们可以请求空投来获取测试资金
    let airdrop_signature = client
        .request_airdrop(&fee_payer.pubkey(), 1_000_000_000)
        .await?;

    // 等待空投交易确认
    // 使用循环不断检查交易是否已确认，确保资金到账后再继续
    loop {
        let confirmed = client.confirm_transaction(&airdrop_signature).await?;
        if confirmed {
            break;
        }
    }

    // 向接收者空投 1 SOL，用于支付账户租金豁免
    // 在 Solana 上，账户需要保持一定数量的 SOL 来免于被回收（租金豁免）
    let recipient_airdrop_signature = client
        .request_airdrop(&recipient.pubkey(), 1_000_000_000)
        .await?;

    // 等待接收者空投确认
    loop {
        let confirmed = client
            .confirm_transaction(&recipient_airdrop_signature)
            .await?;
        if confirmed {
            break;
        }
    }

    // ========================================================================
    // 第三部分：创建代币 Mint 账户
    // ========================================================================
    
    // 生成 Mint 账户的密钥对
    // Mint 账户存储代币的元数据，如总供应量、小数位数、权限等
    let mint = Keypair::new();

    // 获取 Mint 账户所需的最小空间（字节数）
    // Mint::LEN 是 Mint 账户的标准大小
    let mint_space = Mint::LEN;
    
    // 计算创建 Mint 账户所需的最小 SOL 数量（租金豁免）
    // Solana 使用账户模型，每个账户都需要存储数据，因此需要支付租金
    let mint_rent = client
        .get_minimum_balance_for_rent_exemption(mint_space)
        .await?;

    // 创建账户指令：在链上创建一个新账户用于存储 Mint 数据
    // 这个指令告诉 Solana 系统程序创建一个新账户
    // - payer: 支付账户创建费用的地址
    // - new account: 新账户的地址（mint 的公钥）
    // - lamports: 存入账户的 SOL 数量（用于租金豁免）
    // - space: 账户的数据空间大小
    // - program id: 账户所属的程序 ID（这里是 SPL Token 程序）
    let create_account_instruction = system_instruction::create_account(
        &fee_payer.pubkey(), // payer
        &mint.pubkey(),      // new account (mint)
        mint_rent,           // lamports
        mint_space as u64,   // space
        &spl_token::id(),    // program id
    );

    // 初始化 Mint 账户指令：设置代币的基本属性
    // initialize_mint2 是更新版本的初始化函数，支持更多功能
    // - mint: Mint 账户地址
    // - mint_authority: 拥有铸造权限的地址（可以铸造新代币）
    // - freeze_authority: 拥有冻结权限的地址（可以冻结代币账户，可选）
    // - decimals: 小数位数（2 表示最小单位是 0.01）
    let initialize_mint_instruction = initialize_mint2(
        &spl_token::id(),
        &mint.pubkey(),            // mint
        &fee_payer.pubkey(),       // mint authority
        Some(&fee_payer.pubkey()), // freeze authority
        2,                         // decimals
    )?;

    // ========================================================================
    // 第四部分：创建关联代币账户 (Associated Token Account, ATA)
    // ========================================================================
    
    // 计算费用支付者的关联代币账户地址
    // ATA 是一个确定性地址，由所有者地址和 Mint 地址计算得出
    // 每个用户对每个代币类型都有一个唯一的 ATA
    // 使用 ATA 的好处是地址可以预先计算，不需要链上查找
    let source_token_address = get_associated_token_address(
        &fee_payer.pubkey(), // owner
        &mint.pubkey(),      // mint
    );

    // 创建费用支付者的关联代币账户指令
    // 这个指令会创建一个新的代币账户来存储费用支付者持有的代币
    // - funding_address: 支付账户创建费用的地址
    // - wallet_address: 代币账户的所有者
    // - mint_address: 代币的 Mint 地址
    // - token_program_id: SPL Token 程序 ID
    let create_source_ata_instruction = create_associated_token_account(
        &fee_payer.pubkey(), // funding address
        &fee_payer.pubkey(), // wallet address
        &mint.pubkey(),      // mint address
        &spl_token::id(),    // token program id
    );

    // 计算接收者的关联代币账户地址
    let destination_token_address = get_associated_token_address(
        &recipient.pubkey(), // owner
        &mint.pubkey(),      // mint
    );

    // 创建接收者的关联代币账户指令
    // 接收者需要有一个代币账户才能接收代币
    let create_destination_ata_instruction = create_associated_token_account(
        &fee_payer.pubkey(), // funding address
        &recipient.pubkey(), // wallet address
        &mint.pubkey(),      // mint address
        &spl_token::id(),    // token program id
    );

    // ========================================================================
    // 第五部分：铸造代币
    // ========================================================================
    
    // 要铸造的代币数量：100 tokens，由于小数位数为 2，所以是 100_00
    // 实际数量 = 100 * 10^2 = 10,000 最小单位
    let amount = 100_00;

    // 创建铸造代币指令：将新代币铸造到源代币账户
    // mint_to 指令会从 Mint 账户铸造新代币并存入指定的代币账户
    // - mint: Mint 账户地址
    // - destination: 目标代币账户（接收新铸造的代币）
    // - authority: 拥有铸造权限的地址（必须是 mint_authority）
    // - signers: 签名者列表（authority 必须签名）
    // - amount: 要铸造的代币数量（以最小单位计算）
    let mint_to_instruction = mint_to(
        &spl_token::id(),
        &mint.pubkey(),         // mint
        &source_token_address,  // destination
        &fee_payer.pubkey(),    // authority
        &[&fee_payer.pubkey()], // signer
        amount,                 // amount
    )?;

    // ========================================================================
    // 第六部分：构建并发送第一笔交易（创建 Mint + 创建 ATA + 铸造代币）
    // ========================================================================
    
    // 创建交易并添加所有指令
    // 在 Solana 上，可以将多个指令打包到一个交易中，按顺序执行
    // 这样可以确保要么全部成功，要么全部失败（原子性）
    let transaction = Transaction::new_signed_with_payer(
        &[
            create_account_instruction,        // 1. 创建 Mint 账户
            initialize_mint_instruction,       // 2. 初始化 Mint 账户
            create_source_ata_instruction,      // 3. 创建源代币账户
            create_destination_ata_instruction, // 4. 创建目标代币账户
            mint_to_instruction,               // 5. 铸造代币到源账户
        ],
        Some(&fee_payer.pubkey()), // 费用支付者
        &[&fee_payer, &mint],      // 需要签名的密钥对列表
        latest_blockhash,           // 区块哈希（防重放）
    );

    // 发送交易并等待确认
    // send_and_confirm_transaction 会：
    // 1. 发送交易到网络
    // 2. 等待交易被包含在区块中
    // 3. 确认交易已成功执行
    client.send_and_confirm_transaction(&transaction).await?;

    // ========================================================================
    // 第七部分：转账代币
    // ========================================================================
    
    // 获取最新的区块哈希（用于新的交易）
    // 区块哈希有时效性，所以每次新交易都需要获取最新的
    let latest_blockhash = client.get_latest_blockhash().await?;

    // 要转账的代币数量：0.50 tokens，由于小数位数为 2，所以是 50
    // 实际数量 = 0.50 * 10^2 = 50 最小单位
    let transfer_amount = 50;

    // 创建转账指令：从源账户转账代币到目标账户
    // transfer_checked 会验证转账金额和小数位数，更安全
    // - source: 源代币账户（发送方）
    // - mint: Mint 地址（用于验证）
    // - destination: 目标代币账户（接收方）
    // - owner: 源账户的所有者（必须签名）
    // - signers: 签名者列表
    // - amount: 转账数量（以最小单位计算）
    // - decimals: 小数位数（用于验证）
    let transfer_instruction = transfer_checked(
        &spl_token::id(),        // program id
        &source_token_address,   // source
        &mint.pubkey(),          // mint
        &destination_token_address, // destination
        &fee_payer.pubkey(),     // owner of source
        &[&fee_payer.pubkey()],  // signers
        transfer_amount,         // amount
        2,                       // decimals
    )?;

    // 创建转账交易
    let transaction = Transaction::new_signed_with_payer(
        &[transfer_instruction],
        Some(&fee_payer.pubkey()),
        &[&fee_payer],
        latest_blockhash,
    );

    // 发送并确认转账交易
    let transaction_signature = client.send_and_confirm_transaction(&transaction).await?;

    // ========================================================================
    // 第八部分：验证交易结果
    // ========================================================================
    
    // 获取 Mint 账户数据并解析
    // 验证 Mint 账户的状态，包括总供应量等
    let mint_account = client.get_account(&mint.pubkey()).await?;
    let mint_data = Mint::unpack(&mint_account.data)?;

    // 获取源代币账户和目标代币账户的数据
    // 用于验证转账是否成功
    let source_token_account = client.get_account(&source_token_address).await?;
    let destination_token_account = client.get_account(&destination_token_address).await?;

    // 解析代币账户数据
    // TokenAccount 结构包含账户余额、所有者等信息
    use spl_token::state::Account as TokenAccount;
    let source_token_data = TokenAccount::unpack(&source_token_account.data)?;
    let destination_token_data = TokenAccount::unpack(&destination_token_account.data)?;

    // ========================================================================
    // 第九部分：输出结果
    // ========================================================================
    
    println!("Successfully transferred 0.50 tokens from sender to recipient");

    println!("\nMint Address: {}", mint.pubkey());
    println!("{:#?}", mint_data);

    println!("\nSource Token Account Address: {}", source_token_address);
    println!("Token Balance: {}", source_token_data.amount);
    println!("{:#?}", source_token_data);

    println!(
        "\nDestination Token Account Address: {}",
        destination_token_address
    );
    println!("Token Balance: {}", destination_token_data.amount);
    println!("{:#?}", destination_token_data);

    println!("Transaction Signature: {}", transaction_signature);

    Ok(())
}
