use {
    anchor_lang::prelude::*,
    anchor_spl::{
        associated_token::AssociatedToken,
        token::{transfer, Mint, Token, TokenAccount, Transfer},
    },
};

/// 转移代币所需的账户结构
#[derive(Accounts)]
pub struct TransferTokens<'info> {
    #[account(mut)]
    pub sender: Signer<'info>,
    
    pub recipient: SystemAccount<'info>,

    #[account(mut)]
    pub mint_account: Account<'info, Mint>,
    
    // 发送者的 ATA，验证所有权
    #[account(
        mut,
        associated_token::mint = mint_account,
        associated_token::authority = sender,
    )]
    pub sender_token_account: Account<'info, TokenAccount>,
    
    // 接收者的 ATA，如果不存在则自动创建
    #[account(
        init_if_needed,
        payer = sender,
        associated_token::mint = mint_account,
        associated_token::authority = recipient,
    )]
    pub recipient_token_account: Account<'info, TokenAccount>,

    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

/// 在账户之间转移代币
/// 通过 CPI 调用 SPL Token 程序的 transfer 指令
/// amount 会被转换为最小单位（考虑小数位数）
/// SPL Token 程序会自动验证余额和权限
pub fn transfer_tokens(ctx: Context<TransferTokens>, amount: u64) -> Result<()> {
    msg!("Transferring tokens...");
    msg!("Mint: {}", &ctx.accounts.mint_account.to_account_info().key());
    msg!("From Token Address: {}", &ctx.accounts.sender_token_account.key());
    msg!("To Token Address: {}", &ctx.accounts.recipient_token_account.key());

    // CPI 调用 SPL Token 程序转移代币
    // 将数量转换为最小单位：amount * 10^decimals
    transfer(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.sender_token_account.to_account_info(),
                to: ctx.accounts.recipient_token_account.to_account_info(),
                authority: ctx.accounts.sender.to_account_info(),
            },
        ),
        amount * 10u64.pow(ctx.accounts.mint_account.decimals as u32),
    )?;

    msg!("Tokens transferred successfully.");
    Ok(())
}
