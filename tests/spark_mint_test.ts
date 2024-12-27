import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test collection creation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            // Owner can create collection
            Tx.contractCall('spark_mint', 'create-collection', [
                types.uint(100),
                types.utf8("https://api.sparkmint.com/collection/")
            ], deployer.address),
            // Non-owner cannot create collection
            Tx.contractCall('spark_mint', 'create-collection', [
                types.uint(100),
                types.utf8("https://api.sparkmint.com/collection/")
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk().expectUint(1);
        block.receipts[1].result.expectErr().expectUint(100); // err-owner-only
    }
});

Clarinet.test({
    name: "Test NFT minting and metadata",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;

        // First create a collection
        let setup = chain.mineBlock([
            Tx.contractCall('spark_mint', 'create-collection', [
                types.uint(100),
                types.utf8("https://api.sparkmint.com/collection/")
            ], deployer.address)
        ]);

        let block = chain.mineBlock([
            // Mint new NFT
            Tx.contractCall('spark_mint', 'mint-nft', [
                types.uint(1),
                types.utf8("Test NFT"),
                types.utf8("A test NFT description"),
                types.utf8("https://api.sparkmint.com/nft/1.png")
            ], wallet1.address)
        ]);

        const tokenId = block.receipts[0].result.expectOk().expectUint(1);

        // Check metadata
        let metadataBlock = chain.mineBlock([
            Tx.contractCall('spark_mint', 'get-token-metadata', [
                types.uint(tokenId)
            ], deployer.address)
        ]);

        const metadata = metadataBlock.receipts[0].result.expectOk().expectSome();
        assertEquals(metadata['name'].value, "Test NFT");
    }
});

Clarinet.test({
    name: "Test voting mechanism",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;

        // Setup collection and mint NFT
        let setup = chain.mineBlock([
            Tx.contractCall('spark_mint', 'create-collection', [
                types.uint(100),
                types.utf8("https://api.sparkmint.com/collection/")
            ], deployer.address),
            Tx.contractCall('spark_mint', 'mint-nft', [
                types.uint(1),
                types.utf8("Test NFT"),
                types.utf8("A test NFT description"),
                types.utf8("https://api.sparkmint.com/nft/1.png")
            ], wallet1.address)
        ]);

        let block = chain.mineBlock([
            // Multiple users vote on trait
            Tx.contractCall('spark_mint', 'vote-trait', [
                types.uint(1),
                types.utf8("background"),
                types.utf8("blue")
            ], wallet1.address),
            Tx.contractCall('spark_mint', 'vote-trait', [
                types.uint(1),
                types.utf8("background"),
                types.utf8("blue")
            ], wallet2.address)
        ]);

        block.receipts.forEach(receipt => {
            receipt.result.expectOk().expectBool(true);
        });

        // Check vote count
        let voteBlock = chain.mineBlock([
            Tx.contractCall('spark_mint', 'get-trait-votes', [
                types.uint(1),
                types.utf8("background")
            ], deployer.address)
        ]);

        const votes = voteBlock.receipts[0].result.expectOk().expectSome();
        assertEquals(votes['votes'].value, 2);
    }
});