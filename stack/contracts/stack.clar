;; DigitalGavel - Secure NFT Marketplace Smart Contract

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
(define-constant ERR-INVALID-PARAMETERS (err u104))
(define-constant ERR-CONTRACT-MISMATCH (err u105))

;; Data Variables
(define-data-var minimum-bid uint u1000000)
(define-data-var max-listing-duration uint u2592000) ;; 30 days in seconds
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

;; Private Helper Functions
(define-private (is-valid-listing-id (listing-id uint))
    (and (> listing-id u0) (< listing-id (var-get listing-counter)))
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
        ;; Input validation
        (asserts! (> token-id u0) ERR-INVALID-PARAMETERS)
        (asserts! (>= reserve-price (var-get minimum-bid)) ERR-INVALID-PARAMETERS)
        (asserts! (> duration u0) ERR-INVALID-PARAMETERS)
        (asserts! (<= duration (var-get max-listing-duration)) ERR-INVALID-PARAMETERS)
        
        ;; Verify NFT ownership
        (let ((nft-owner (try! (contract-call? nft-contract get-owner token-id))))
            (asserts! (is-eq nft-owner tx-sender) ERR-UNAUTHORIZED)
            
            ;; Transfer NFT to contract
            (try! (contract-call? nft-contract transfer token-id tx-sender (as-contract tx-sender)))
            
            ;; Create listing
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
            
            ;; Increment listing counter
            (var-set listing-counter (+ new-listing-id u1))
            (ok new-listing-id)
        )
    )
)

(define-public (place-bid (listing-id uint) (bid-amount uint))
    (let (
        (listing (unwrap! (map-get? marketplace-listings { listing-id: listing-id }) ERR-LISTING-NOT-FOUND))
        (current-time (var-get current-timestamp))
    )
        ;; Additional input validations
        (asserts! (is-valid-listing-id listing-id) ERR-INVALID-PARAMETERS)
        (asserts! (> bid-amount u0) ERR-INVALID-PARAMETERS)
        
        ;; Auction status checks
        (asserts! (get is-active listing) ERR-LISTING-CLOSED)
        (asserts! (< current-time (get expiration listing)) ERR-LISTING-CLOSED)
        (asserts! (>= bid-amount (get reserve-price listing)) ERR-BID-TOO-LOW)
        (asserts! (> bid-amount (get highest-bid listing)) ERR-BID-TOO-LOW)
        
        ;; Transfer bid amount
        (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
        
        ;; Refund previous highest bidder if exists
        (match (get highest-bidder listing) previous-bidder
            (try! (as-contract (stx-transfer? (get highest-bid listing) tx-sender previous-bidder)))
            true
        )
        
        ;; Update listing with new bid
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
        ;; Additional input validations
        (asserts! (is-valid-listing-id listing-id) ERR-INVALID-PARAMETERS)
        
        ;; Verify NFT contract matches original listing
        (asserts! (is-eq (contract-of nft-contract) (get nft-contract listing)) ERR-CONTRACT-MISMATCH)
        
        ;; Auction status checks
        (asserts! (get is-active listing) ERR-LISTING-CLOSED)
        (asserts! (>= current-time (get expiration listing)) ERR-LISTING-CLOSED)
        
        ;; Mark listing as inactive
        (map-set marketplace-listings
            { listing-id: listing-id }
            (merge listing { is-active: false })
        )
        
        ;; Handle NFT transfer based on bidding status
        (if (is-some (get highest-bidder listing))
            (let (
                (winner (unwrap! (get highest-bidder listing) ERR-LISTING-NOT-FOUND))
            )
                ;; Transfer NFT to highest bidder
                (try! (as-contract 
                    (contract-call? 
                        nft-contract
                        transfer
                        (get token-id listing)
                        tx-sender
                        winner
                    )
                ))
                
                ;; Transfer funds to seller
                (try! (as-contract (stx-transfer? (get highest-bid listing) tx-sender (get seller listing))))
                (ok true)
            )
            (begin
                ;; Return NFT to original seller if no bids
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

;; Administrative Functions
(define-public (update-system-time (new-timestamp uint))
    (begin
        (asserts! (is-eq tx-sender ADMIN) ERR-UNAUTHORIZED)
        (asserts! (>= new-timestamp (var-get current-timestamp)) ERR-INVALID-PARAMETERS)
        (var-set current-timestamp new-timestamp)
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-listing-details (listing-id uint))
    (map-get? marketplace-listings { listing-id: listing-id })
)

(define-read-only (get-current-timestamp)
    (var-get current-timestamp)
)