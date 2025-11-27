use {
    anchor_lang::prelude::*,
    anchor_spl::token::{burn, Burn, Mint, Token, TokenAccount},
};

/// 销毁代币所需的账户结构
#[derive(Accounts)]
pub struct BurnTokens<'info> {
    #[account(mut)]
    pub owner: Signer<'info>,
    
    #[account(mut)]
    pub mint_account: Account<'info, Mint>,
    
    // 代币持有者的 ATA，将被销毁的代币所在账户
    #[account(
        mut,
        associated_token::mint = mint_account,
        associated_token::authority = owner,
    )]
    pub token_account: Account<'info, TokenAccount>,

    pub token_program: Program<'info, Token>,
}

/// 销毁代币
/// 通过 CPI 调用 SPL Token 程序的 burn 指令
/// amount 会被转换为最小单位（考虑小数位数）
/// SPL Token 程序会自动验证余额和权限
pub fn burn_tokens(ctx: Context<BurnTokens>, amount: u64) -> Result<()> {
    msg!("Burning tokens...");
    msg!("Mint: {}", &ctx.accounts.mint_account.to_account_info().key());
    msg!("Token Address: {}", &ctx.accounts.token_account.key());
    msg!("Amount: {}", amount);

    // CPI 调用 SPL Token 程序销毁代币
    // 将数量转换为最小单位：amount * 10^decimals
    burn(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Burn {
                mint: ctx.accounts.mint_account.to_account_info(),
                from: ctx.accounts.token_account.to_account_info(),
                authority: ctx.accounts.owner.to_account_info(),
            },
        ),
        amount * 10u64.pow(ctx.accounts.mint_account.decimals as u32),
    )?;

    msg!("Tokens burned successfully.");
    Ok(())
}

