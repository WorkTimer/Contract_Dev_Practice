use {
    anchor_lang::prelude::*,
    anchor_spl::{
        associated_token::AssociatedToken,
        token::{mint_to, Mint, MintTo, Token, TokenAccount},
    },
};

/// 铸造代币所需的账户结构
#[derive(Accounts)]
pub struct MintToken<'info> {
    #[account(mut)]
    pub mint_authority: Signer<'info>,

    pub recipient: SystemAccount<'info>,
    
    #[account(mut)]
    pub mint_account: Account<'info, Mint>,
    
    // 接收者的 ATA，如果不存在则自动创建
    #[account(
        init_if_needed,
        payer = mint_authority,
        associated_token::mint = mint_account,
        associated_token::authority = recipient,
    )]
    pub associated_token_account: Account<'info, TokenAccount>,

    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

/// 铸造代币到指定账户
/// 通过 CPI 调用 SPL Token 程序的 mint_to 指令
/// amount 会被转换为最小单位（考虑小数位数）
pub fn mint_token(ctx: Context<MintToken>, amount: u64) -> Result<()> {
    msg!("Minting tokens to associated token account...");
    msg!("Mint: {}", &ctx.accounts.mint_account.key());
    msg!("Token Address: {}", &ctx.accounts.associated_token_account.key());

    // CPI 调用 SPL Token 程序铸造代币
    // 将数量转换为最小单位：amount * 10^decimals
    mint_to(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            MintTo {
                mint: ctx.accounts.mint_account.to_account_info(),
                to: ctx.accounts.associated_token_account.to_account_info(),
                authority: ctx.accounts.mint_authority.to_account_info(),
            },
        ),
        amount * 10u64.pow(ctx.accounts.mint_account.decimals as u32),
    )?;

    msg!("Token minted successfully.");
    Ok(())
}
