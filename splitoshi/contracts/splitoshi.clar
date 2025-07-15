;; Splitoshi - NFT Fractionalization Contract
;; Allows users to split expensive NFTs into smaller tradeable shares

;; Define NFT trait inline
(define-trait nft-trait
  (
    (transfer (uint principal principal) (response bool uint))
    (get-owner (uint) (response (optional principal) uint))
  )
)

;; Constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_SHARES (err u101))
(define-constant ERR_VAULT_NOT_FOUND (err u102))
(define-constant ERR_INSUFFICIENT_SHARES (err u103))
(define-constant ERR_VAULT_ALREADY_EXISTS (err u104))
(define-constant ERR_INVALID_PRICE (err u105))
(define-constant ERR_ALREADY_LISTED (err u106))
(define-constant ERR_NOT_LISTED (err u107))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u108))
(define-constant ERR_NFT_TRANSFER_FAILED (err u109))

;; Data Variables
(define-data-var next-vault-id uint u1)

;; Data Maps
(define-map vaults
  { vault-id: uint }
  {
    nft-contract: principal,
    nft-id: uint,
    total-shares: uint,
    creator: principal,
    name: (string-ascii 50),
    active: bool
  }
)

(define-map user-shares
  { vault-id: uint, owner: principal }
  { shares: uint }
)

(define-map share-listings
  { vault-id: uint, seller: principal }
  { 
    shares-for-sale: uint,
    price-per-share: uint
  }
)

;; Read-only functions
(define-read-only (get-vault-info (vault-id uint))
  (map-get? vaults { vault-id: vault-id })
)

(define-read-only (get-user-shares (vault-id uint) (owner principal))
  (default-to u0 (get shares (map-get? user-shares { vault-id: vault-id, owner: owner })))
)

(define-read-only (get-share-listing (vault-id uint) (seller principal))
  (map-get? share-listings { vault-id: vault-id, seller: seller })
)

(define-read-only (get-next-vault-id)
  (var-get next-vault-id)
)

;; Private functions
;; Helper function to verify NFT ownership
(define-private (verify-nft-ownership (nft-contract <nft-trait>) (nft-id uint) (owner principal))
  (match (contract-call? nft-contract get-owner nft-id)
    success (is-eq (some owner) success)
    error false
  )
)

;; Public functions

;; Create a new vault by depositing an NFT and splitting it into shares
(define-public (create-vault 
  (nft-contract <nft-trait>) 
  (nft-id uint) 
  (total-shares uint) 
  (vault-name (string-ascii 50))
)
  (let
    (
      (vault-id (var-get next-vault-id))
    )
    (asserts! (> total-shares u0) ERR_INVALID_SHARES)
    (asserts! (is-none (map-get? vaults { vault-id: vault-id })) ERR_VAULT_ALREADY_EXISTS)
    
    ;; Verify caller owns the NFT
    (asserts! (verify-nft-ownership nft-contract nft-id tx-sender) ERR_NOT_AUTHORIZED)
    
    ;; Transfer NFT to contract
    (try! (contract-call? nft-contract transfer nft-id tx-sender (as-contract tx-sender)))
    
    ;; Create vault record
    (map-set vaults
      { vault-id: vault-id }
      {
        nft-contract: (contract-of nft-contract),
        nft-id: nft-id,
        total-shares: total-shares,
        creator: tx-sender,
        name: vault-name,
        active: true
      }
    )
    
    ;; Give all shares to creator initially
    (map-set user-shares
      { vault-id: vault-id, owner: tx-sender }
      { shares: total-shares }
    )
    
    ;; Increment vault ID for next vault
    (var-set next-vault-id (+ vault-id u1))
    
    (ok vault-id)
  )
)

;; Transfer shares between users
(define-public (transfer-shares (vault-id uint) (amount uint) (recipient principal))
  (let
    (
      (sender-shares (get-user-shares vault-id tx-sender))
      (recipient-shares (get-user-shares vault-id recipient))
    )
    (asserts! (>= sender-shares amount) ERR_INSUFFICIENT_SHARES)
    (asserts! (> amount u0) ERR_INVALID_SHARES)
    
    ;; Update sender's shares
    (map-set user-shares
      { vault-id: vault-id, owner: tx-sender }
      { shares: (- sender-shares amount) }
    )
    
    ;; Update recipient's shares
    (map-set user-shares
      { vault-id: vault-id, owner: recipient }
      { shares: (+ recipient-shares amount) }
    )
    
    (ok true)
  )
)

;; List shares for sale
(define-public (list-shares-for-sale (vault-id uint) (shares-amount uint) (price-per-share uint))
  (let
    (
      (user-shares-balance (get-user-shares vault-id tx-sender))
    )
    (asserts! (>= user-shares-balance shares-amount) ERR_INSUFFICIENT_SHARES)
    (asserts! (> shares-amount u0) ERR_INVALID_SHARES)
    (asserts! (> price-per-share u0) ERR_INVALID_PRICE)
    (asserts! (is-none (map-get? share-listings { vault-id: vault-id, seller: tx-sender })) ERR_ALREADY_LISTED)
    
    ;; Create listing
    (map-set share-listings
      { vault-id: vault-id, seller: tx-sender }
      {
        shares-for-sale: shares-amount,
        price-per-share: price-per-share
      }
    )
    
    (ok true)
  )
)

;; Buy shares from a listing
(define-public (buy-shares (vault-id uint) (seller principal) (shares-amount uint))
  (let
    (
      (listing (unwrap! (map-get? share-listings { vault-id: vault-id, seller: seller }) ERR_NOT_LISTED))
      (price-per-share (get price-per-share listing))
      (available-shares (get shares-for-sale listing))
      (total-cost (* shares-amount price-per-share))
      (seller-shares (get-user-shares vault-id seller))
      (buyer-shares (get-user-shares vault-id tx-sender))
    )
    (asserts! (<= shares-amount available-shares) ERR_INSUFFICIENT_SHARES)
    (asserts! (>= seller-shares shares-amount) ERR_INSUFFICIENT_SHARES)
    
    ;; Transfer STX payment to seller
    (try! (stx-transfer? total-cost tx-sender seller))
    
    ;; Transfer shares from seller to buyer
    (map-set user-shares
      { vault-id: vault-id, owner: seller }
      { shares: (- seller-shares shares-amount) }
    )
    
    (map-set user-shares
      { vault-id: vault-id, owner: tx-sender }
      { shares: (+ buyer-shares shares-amount) }
    )
    
    ;; Update or remove listing
    (if (is-eq shares-amount available-shares)
      (map-delete share-listings { vault-id: vault-id, seller: seller })
      (map-set share-listings
        { vault-id: vault-id, seller: seller }
        {
          shares-for-sale: (- available-shares shares-amount),
          price-per-share: price-per-share
        }
      )
    )
    
    (ok true)
  )
)

;; Remove shares from sale
(define-public (remove-shares-from-sale (vault-id uint))
  (begin
    (asserts! (is-some (map-get? share-listings { vault-id: vault-id, seller: tx-sender })) ERR_NOT_LISTED)
    
    (map-delete share-listings { vault-id: vault-id, seller: tx-sender })
    
    (ok true)
  )
)

;; Redeem NFT (requires owning ALL shares)
(define-public (redeem-nft (vault-id uint) (nft-contract <nft-trait>))
  (let
    (
      (vault-info (unwrap! (map-get? vaults { vault-id: vault-id }) ERR_VAULT_NOT_FOUND))
      (user-shares-balance (get-user-shares vault-id tx-sender))
      (total-shares (get total-shares vault-info))
    )
    (asserts! (is-eq user-shares-balance total-shares) ERR_INSUFFICIENT_SHARES)
    (asserts! (get active vault-info) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (contract-of nft-contract) (get nft-contract vault-info)) ERR_NOT_AUTHORIZED)
    
    ;; Transfer NFT back to user
    (try! (as-contract (contract-call? nft-contract transfer (get nft-id vault-info) (as-contract tx-sender) tx-sender)))
    
    ;; Mark vault as inactive
    (map-set vaults
      { vault-id: vault-id }
      (merge vault-info { active: false })
    )
    
    ;; Remove user's shares
    (map-delete user-shares { vault-id: vault-id, owner: tx-sender })
    
    (ok true)
  )
)