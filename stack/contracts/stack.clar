;; DigitalGavel - Minimal NFT Marketplace Smart Contract

(define-trait nft-standard
    (
        (transfer (uint principal principal) (response bool uint))
        (get-owner (uint) (response principal uint))
    )
)

;; Constants and Error Codes
(define-constant ADMIN tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-LISTING-NOT-FOUND (err u101))
(define-constant ERR-LISTING-CLOSED (err u102))
(define-constant ERR-BID-TOO-LOW (err u103))

;; Data Variables
(define-data-var minimum-bid uint u1000000)
(define-data-var listing-counter uint u0)
(define-data-var current-timestamp uint u0)

;; Data Maps
(define-map marketplace-listings
    { listing-id: uint }
    {
        seller: principal,
        nft-contract: principal,
        token-id: uint,
        reserve-price: uint,
        highest-bid: uint,
        highest-bidder: (optional principal),
        expiration: uint,
        is-active: bool
    }
)

;; Public Functions
(define-public (create-listing 
    (nft-contract <nft-standard>)
    (token-id uint)
    (reserve-price uint)
    (duration uint))
    (let (
        (new-listing-id (var-get listing-counter))
        (current-time (var-get current-timestamp))
    )
        (asserts! (is-eq tx-sender (try! (contract-call? nft-contract get-owner token-id))) ERR-UNAUTHORIZED)
        
        (try! (contract-call? nft-contract transfer token-id tx-sender (as-contract tx-sender)))
        
        (map-set marketplace-listings
            { listing-id: new-listing-id }
            {
                seller: tx-sender,
                nft-contract: (contract-of nft-contract),
                token-id: token-id,
                reserve-price: reserve-price,
                highest-bid: u0,
                highest-bidder: none,
                expiration: (+ current-time duration),
                is-active: true
            }
        )
        
        (var-set listing-counter (+ new-listing-id u1))
        (ok new-listing-id)
    )
)

(define-public (place-bid (listing-id uint) (bid-amount uint))
    (let (
        (listing (unwrap! (map-get? marketplace-listings { listing-id: listing-id }) ERR-LISTING-NOT-FOUND))
        (current-time (var-get current-timestamp))
    )
        (asserts! (get is-active listing) ERR-LISTING-CLOSED)
        (asserts! (< current-time (get expiration listing)) ERR-LISTING-CLOSED)
        (asserts! (> bid-amount (get highest-bid listing)) ERR-BID-TOO-LOW)
        
        (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
        
        (match (get highest-bidder listing) previous-bidder
            (try! (as-contract (stx-transfer? (get highest-bid listing) tx-sender previous-bidder)))
            true
        )
        
        (map-set marketplace-listings
            { listing-id: listing-id }
            (merge listing {
                highest-bid: bid-amount,
                highest-bidder: (some tx-sender)
            })
        )
        
        (ok true)
    )
)

(define-public (conclude-listing (listing-id uint) (nft-contract <nft-standard>))
    (let (
        (listing (unwrap! (map-get? marketplace-listings { listing-id: listing-id }) ERR-LISTING-NOT-FOUND))
        (current-time (var-get current-timestamp))
    )
        (asserts! (get is-active listing) ERR-LISTING-CLOSED)
        (asserts! (>= current-time (get expiration listing)) ERR-LISTING-CLOSED)
        
        (map-set marketplace-listings
            { listing-id: listing-id }
            (merge listing { is-active: false })
        )
        
        (if (is-some (get highest-bidder listing))
            (let (
                (winner (unwrap! (get highest-bidder listing) ERR-LISTING-NOT-FOUND))
            )
                (try! (as-contract 
                    (contract-call? 
                        nft-contract
                        transfer
                        (get token-id listing)
                        tx-sender
                        winner
                    )
                ))
                (try! (as-contract (stx-transfer? (get highest-bid listing) tx-sender (get seller listing))))
                (ok true)
            )
            (begin
                (try! (as-contract 
                    (contract-call? 
                        nft-contract
                        transfer
                        (get token-id listing)
                        tx-sender
                        (get seller listing)
                    )
                ))
                (ok true)
            )
        )
    )
)

;; Read-only Functions
(define-read-only (get-listing-details (listing-id uint))
    (map-get? marketplace-listings { listing-id: listing-id })
)