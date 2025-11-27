import * as anchor from "@coral-xyz/anchor";
import { getAssociatedTokenAddressSync } from "@solana/spl-token";
import { Keypair } from "@solana/web3.js";
import { BN } from "bn.js";
import type { TransferTokens } from "../target/types/transfer_tokens";

describe("Transfer Tokens", () => {
	const provider = anchor.AnchorProvider.env();
	anchor.setProvider(provider);
	const payer = provider.wallet as anchor.Wallet;
	const program = anchor.workspace
		.TransferTokens as anchor.Program<TransferTokens>;

	// 代币元数据配置
	const metadata = {
		name: "Practice Token",
		symbol: "PRAC",
		uri: "https://raw.githubusercontent.com/WorkTimer/Contract_Dev_Practice/refs/heads/main/task4/spl-token.json",
	};

	// 生成密钥对作为代币铸造账户地址
	const mintKeypair = new Keypair();

	// 生成密钥对作为接收者钱包地址
	const recipient = new Keypair();

	// 计算支付者和接收者的 ATA 地址
	const senderTokenAddress = getAssociatedTokenAddressSync(
		mintKeypair.publicKey,
		payer.publicKey,
	);

	const recepientTokenAddress = getAssociatedTokenAddressSync(
		mintKeypair.publicKey,
		recipient.publicKey,
	);

	it("Create an SPL Token!", async () => {
		const transactionSignature = await program.methods
			.createToken(metadata.name, metadata.symbol, metadata.uri)
			.accounts({
				payer: payer.publicKey,
				mintAccount: mintKeypair.publicKey,
			})
			.signers([mintKeypair])
			.rpc();

		console.log("Success!");
		console.log(`   Mint Address: ${mintKeypair.publicKey}`);
		console.log(`   Transaction Signature: ${transactionSignature}`);
	});

	it("Mint tokens!", async () => {
		// 铸造数量（程序内部会转换为最小单位）
		const amount = new BN(100);

		const transactionSignature = await program.methods
			.mintToken(amount)
			.accounts({
				mintAuthority: payer.publicKey,
				recipient: payer.publicKey,
				mintAccount: mintKeypair.publicKey,
			})
			.rpc();

		console.log("Success!");
		console.log(`   Associated Token Account Address: ${senderTokenAddress}`);
		console.log(`   Transaction Signature: ${transactionSignature}`);
	});

	it("Transfer tokens!", async () => {
		// 转移数量（程序内部会转换为最小单位）
		const amount = new BN(50);

		const transactionSignature = await program.methods
			.transferTokens(amount)
			.accounts({
				sender: payer.publicKey,
				recipient: recipient.publicKey,
				mintAccount: mintKeypair.publicKey,
			})
			.rpc();

		console.log("Success!");
		console.log(`   Transaction Signature: ${transactionSignature}`);
	});

	it("Burn tokens!", async () => {
		// 销毁数量（程序内部会转换为最小单位）
		const amount = new BN(25);

		const transactionSignature = await program.methods
			.burnTokens(amount)
			.accounts({
				owner: payer.publicKey,
				mintAccount: mintKeypair.publicKey,
			})
			.rpc();

		console.log("Success!");
		console.log(`   Transaction Signature: ${transactionSignature}`);
	});
});
