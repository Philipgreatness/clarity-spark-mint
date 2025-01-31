;; SparkMint Contract
;; Dynamic Community NFT Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-not-authorized (err u103))
(define-constant err-insufficient-stake (err u104))
(define-constant min-stake-amount u1000000)
(define-constant reward-rate u100) ;; 1% rewards per block

;; Define NFT token
(define-non-fungible-token spark-nft uint)

;; Define fungible token for staking rewards
(define-fungible-token spark-token)

;; Data Maps
(define-map nft-metadata
    uint 
    {
        name: (string-utf8 256),
        description: (string-utf8 1024),
        image-uri: (string-utf8 256),
        attributes: (list 10 {trait: (string-utf8 64), value: (string-utf8 64)})
    }
)

(define-map collection-data
    uint
    {
        creator: principal,
        max-supply: uint,
        current-supply: uint,
        base-uri: (string-utf8 256)
    }
)

(define-map token-votes
    {token-id: uint, trait: (string-utf8 64)}
    {votes: uint}
)

(define-map staking-positions
    principal
    {
        amount: uint,
        start-block: uint,
        last-claim: uint
    }
)

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var last-collection-id uint u0)
(define-data-var total-staked uint u0)

;; Public Functions

;; Create new NFT collection
(define-public (create-collection (max-supply uint) (base-uri (string-utf8 256)))
    (let 
        (
            (collection-id (+ (var-get last-collection-id) u1))
        )
        (if (is-eq tx-sender contract-owner)
            (begin
                (map-set collection-data collection-id
                    {
                        creator: tx-sender,
                        max-supply: max-supply,
                        current-supply: u0,
                        base-uri: base-uri
                    }
                )
                (var-set last-collection-id collection-id)
                (ok collection-id)
            )
            err-owner-only
        )
    )
)

;; Stake tokens to earn rewards
(define-public (stake-tokens (amount uint))
    (let
        (
            (sender tx-sender)
            (current-stake (default-to {amount: u0, start-block: block-height, last-claim: block-height} 
                (map-get? staking-positions sender)))
        )
        (asserts! (>= amount min-stake-amount) err-insufficient-stake)
        (try! (stx-transfer? amount sender (as-contract tx-sender)))
        (map-set staking-positions sender
            {
                amount: (+ amount (get amount current-stake)),
                start-block: block-height,
                last-claim: block-height
            }
        )
        (var-set total-staked (+ (var-get total-staked) amount))
        (ok true)
    )
)

;; Claim staking rewards
(define-public (claim-rewards)
    (let
        (
            (sender tx-sender)
            (position (unwrap! (map-get? staking-positions sender) err-not-found))
            (blocks-elapsed (- block-height (get last-claim position)))
            (reward-amount (* (/ (* (get amount position) reward-rate) u10000) blocks-elapsed))
        )
        (try! (ft-mint? spark-token reward-amount sender))
        (map-set staking-positions sender
            (merge position {last-claim: block-height})
        )
        (ok reward-amount)
    )
)

;; Unstake tokens
(define-public (unstake-tokens)
    (let
        (
            (sender tx-sender)
            (position (unwrap! (map-get? staking-positions sender) err-not-found))
        )
        (try! (as-contract (stx-transfer? (get amount position) tx-sender sender)))
        (var-set total-staked (- (var-get total-staked) (get amount position)))
        (map-delete staking-positions sender)
        (ok true)
    )
)

;; Original functions remain unchanged...
[previous contract functions]

;; New read-only functions
(define-read-only (get-staking-position (staker principal))
    (ok (map-get? staking-positions staker))
)

(define-read-only (get-total-staked)
    (ok (var-get total-staked))
)
