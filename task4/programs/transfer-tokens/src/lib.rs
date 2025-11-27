use anchor_lang::prelude::*;

pub mod instructions;
use instructions::*;

// 程序 ID
declare_id!("ABw4Sw54Hka5hkmhrQ3bMn2XUksAHtoTeqdhrNxQeQgF");

#[program]
pub mod transfer_tokens {
    use super::*;

    /// 创建新的 SPL Token
    /// 初始化 Mint 账户并创建元数据账户
    pub fn create_token(
        ctx: Context<CreateToken>,
        token_title: String,
        token_symbol: String,
        token_uri: String,
    ) -> Result<()> {
        create::create_token(ctx, token_title, token_symbol, token_uri)
    }

    /// 铸造代币到指定账户
    /// 通过 CPI 调用 SPL Token 程序的 mint_to 指令
    pub fn mint_token(ctx: Context<MintToken>, amount: u64) -> Result<()> {
        mint::mint_token(ctx, amount)
    }

    /// 在账户之间转移代币
    /// 通过 CPI 调用 SPL Token 程序的 transfer 指令
    pub fn transfer_tokens(ctx: Context<TransferTokens>, amount: u64) -> Result<()> {
        transfer::transfer_tokens(ctx, amount)
    }

    /// 销毁代币
    /// 通过 CPI 调用 SPL Token 程序的 burn 指令
    pub fn burn_tokens(ctx: Context<BurnTokens>, amount: u64) -> Result<()> {
        burn::burn_tokens(ctx, amount)
    }
}
