[previous test content]

Clarinet.test({
    name: "Test staking mechanism",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            // Stake tokens
            Tx.contractCall('spark_mint', 'stake-tokens', [
                types.uint(1000000)
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk().expectBool(true);

        // Mine some blocks to accumulate rewards
        chain.mineEmptyBlock(10);

        let rewardBlock = chain.mineBlock([
            Tx.contractCall('spark_mint', 'claim-rewards', [], wallet1.address)
        ]);

        rewardBlock.receipts[0].result.expectOk();

        // Check staking position
        let positionBlock = chain.mineBlock([
            Tx.contractCall('spark_mint', 'get-staking-position', [
                types.principal(wallet1.address)
            ], deployer.address)
        ]);

        positionBlock.receipts[0].result.expectOk().expectSome();
    }
});
