;; SparkMint Contract
;; Dynamic Community NFT Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-not-authorized (err u103))

;; Define NFT token
(define-non-fungible-token spark-nft uint)

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

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var last-collection-id uint u0)

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

;; Mint new NFT
(define-public (mint-nft (collection-id uint) (name (string-utf8 256)) (description (string-utf8 1024)) (image-uri (string-utf8 256)))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
            (collection (unwrap! (map-get? collection-data collection-id) err-not-found))
        )
        (asserts! (< (get current-supply collection) (get max-supply collection)) err-already-exists)
        (try! (nft-mint? spark-nft token-id tx-sender))
        (map-set nft-metadata token-id
            {
                name: name,
                description: description,
                image-uri: image-uri,
                attributes: (list)
            }
        )
        (map-set collection-data collection-id
            (merge collection {current-supply: (+ (get current-supply collection) u1)})
        )
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

;; Vote on NFT trait
(define-public (vote-trait (token-id uint) (trait (string-utf8 64)) (value (string-utf8 64)))
    (let
        (
            (vote-key {token-id: token-id, trait: trait})
            (current-votes (default-to {votes: u0} (map-get? token-votes vote-key)))
        )
        (asserts! (is-some (map-get? nft-metadata token-id)) err-not-found)
        (map-set token-votes vote-key
            {votes: (+ (get votes current-votes) u1)}
        )
        (ok true)
    )
)

;; Transfer NFT
(define-public (transfer (token-id uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender (unwrap! (nft-get-owner? spark-nft token-id) err-not-found)) err-not-authorized)
        (try! (nft-transfer? spark-nft token-id tx-sender recipient))
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-token-metadata (token-id uint))
    (ok (map-get? nft-metadata token-id))
)

(define-read-only (get-collection-info (collection-id uint))
    (ok (map-get? collection-data collection-id))
)

(define-read-only (get-trait-votes (token-id uint) (trait (string-utf8 64)))
    (ok (map-get? token-votes {token-id: token-id, trait: trait}))
)