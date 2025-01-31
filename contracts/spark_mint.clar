;; SparkMint Contract
;; Dynamic Community NFT Platform

;; Constants 
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-not-authorized (err u103))
(define-constant err-insufficient-stake (err u104))
(define-constant err-cooldown-active (err u105))
(define-constant min-stake-amount u1000000)
(define-constant reward-rate u100) ;; 1% rewards per block
(define-constant governance-threshold u10000000) ;; 10M minimum for governance
(define-constant unstake-cooldown u144) ;; 24 hour cooldown (in blocks)

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
        last-claim: uint,
        cooldown-start: (optional uint),
        voting-power: uint
    }
)

(define-map governance-proposals
    uint 
    {
        proposer: principal,
        title: (string-utf8 256),
        description: (string-utf8 1024),
        start-block: uint,
        end-block: uint,
        for-votes: uint,
        against-votes: uint,
        executed: bool
    }
)

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var last-collection-id uint u0)
(define-data-var total-staked uint u0)
(define-data-var last-proposal-id uint u0)
(define-data-var dynamic-reward-rate uint u100)

;; Enhanced Staking Functions

(define-public (stake-tokens (amount uint))
    (let
        (
            (sender tx-sender)
            (current-stake (default-to {amount: u0, start-block: block-height, last-claim: block-height, cooldown-start: none, voting-power: u0}
                (map-get? staking-positions sender)))
        )
        (asserts! (>= amount min-stake-amount) err-insufficient-stake)
        (try! (stx-transfer? amount sender (as-contract tx-sender)))
        (map-set staking-positions sender
            {
                amount: (+ amount (get amount current-stake)),
                start-block: block-height,
                last-claim: block-height,
                cooldown-start: none,
                voting-power: (calculate-voting-power (+ amount (get amount current-stake)))
            }
        )
        (var-set total-staked (+ (var-get total-staked) amount))
        (ok true)
    )
)

(define-public (initiate-unstake)
    (let
        (
            (sender tx-sender)
            (position (unwrap! (map-get? staking-positions sender) err-not-found))
        )
        (asserts! (is-none (get cooldown-start position)) err-cooldown-active)
        (map-set staking-positions sender
            (merge position {cooldown-start: (some block-height)})
        )
        (ok true)
    )
)

(define-public (complete-unstake)
    (let
        (
            (sender tx-sender)
            (position (unwrap! (map-get? staking-positions sender) err-not-found))
            (cooldown-block (unwrap! (get cooldown-start position) err-not-found))
        )
        (asserts! (>= (- block-height cooldown-block) unstake-cooldown) err-cooldown-active)
        (try! (as-contract (stx-transfer? (get amount position) tx-sender sender)))
        (var-set total-staked (- (var-get total-staked) (get amount position)))
        (map-delete staking-positions sender)
        (ok true)
    )
)

;; Governance Functions

(define-public (create-proposal (title (string-utf8 256)) (description (string-utf8 1024)) (duration uint))
    (let
        (
            (sender tx-sender)
            (position (unwrap! (map-get? staking-positions sender) err-not-found))
            (proposal-id (+ (var-get last-proposal-id) u1))
        )
        (asserts! (>= (get amount position) governance-threshold) err-insufficient-stake)
        (map-set governance-proposals proposal-id
            {
                proposer: sender,
                title: title,
                description: description,
                start-block: block-height,
                end-block: (+ block-height duration),
                for-votes: u0,
                against-votes: u0,
                executed: false
            }
        )
        (var-set last-proposal-id proposal-id)
        (ok proposal-id)
    )
)

(define-public (vote (proposal-id uint) (support bool))
    (let
        (
            (sender tx-sender)
            (position (unwrap! (map-get? staking-positions sender) err-not-found))
            (proposal (unwrap! (map-get? governance-proposals proposal-id) err-not-found))
            (voting-power (get voting-power position))
        )
        (asserts! (< block-height (get end-block proposal)) err-not-authorized)
        (asserts! (not (get executed proposal)) err-not-authorized)
        (map-set governance-proposals proposal-id
            (merge proposal 
                {
                    for-votes: (if support (+ (get for-votes proposal) voting-power) (get for-votes proposal)),
                    against-votes: (if (not support) (+ (get against-votes proposal) voting-power) (get against-votes proposal))
                }
            )
        )
        (ok true)
    )
)

;; Dynamic Reward Rate Function
(define-public (update-reward-rate (new-rate uint))
    (let
        (
            (proposal-id (var-get last-proposal-id))
            (proposal (unwrap! (map-get? governance-proposals proposal-id) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> (get for-votes proposal) (get against-votes proposal)) err-not-authorized)
        (var-set dynamic-reward-rate new-rate)
        (ok true)
    )
)

;; Helper Functions
(define-private (calculate-voting-power (amount uint))
    (/ amount u1000000)
)

;; Previous functions remain unchanged...
[previous contract functions]
