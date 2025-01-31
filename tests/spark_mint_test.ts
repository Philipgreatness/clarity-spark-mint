Clarinet.test({
    name: "Test enhanced staking and governance features",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Test staking with cooldown
        let block = chain.mineBlock([
            Tx.contractCall('spark_mint', 'stake-tokens', [
                types.uint(10000000) // 10M uSTX
            ], wallet1.address)
        ]);
        block.receipts[0].result.expectOk().expectBool(true);

        // Test proposal creation
        let proposalBlock = chain.mineBlock([
            Tx.contractCall('spark_mint', 'create-proposal', [
                types.utf8("Test Proposal"),
                types.utf8("Description"),
                types.uint(100) // Duration
            ], wallet1.address)
        ]);
        proposalBlock.receipts[0].result.expectOk().expectUint(1);

        // Test voting
        let voteBlock = chain.mineBlock([
            Tx.contractCall('spark_mint', 'vote', [
                types.uint(1), // Proposal ID
                types.bool(true) // Support
            ], wallet1.address)
        ]);
        voteBlock.receipts[0].result.expectOk().expectBool(true);

        // Test unstaking process
        let initiateUnstake = chain.mineBlock([
            Tx.contractCall('spark_mint', 'initiate-unstake', [], wallet1.address)
        ]);
        initiateUnstake.receipts[0].result.expectOk().expectBool(true);

        // Mine blocks to simulate cooldown
        chain.mineEmptyBlock(144);

        let completeUnstake = chain.mineBlock([
            Tx.contractCall('spark_mint', 'complete-unstake', [], wallet1.address)
        ]);
        completeUnstake.receipts[0].result.expectOk().expectBool(true);
    }
});
