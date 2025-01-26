;; SIP-010 Compliant Fungible Token
;; Will be used with the vesting contract

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))

;; Token Properties
(define-fungible-token chain-token)

;; SIP-010 Standard Functions
(define-read-only (get-name)
    (ok "ChainToken"))

(define-read-only (get-symbol)
    (ok "CHT"))

(define-read-only (get-decimals)
    (ok u6))

(define-read-only (get-balance (account principal))
    (ok (ft-get-balance chain-token account)))

(define-read-only (get-total-supply)
    (ok (ft-get-supply chain-token)))

(define-read-only (get-token-uri)
    (ok (some "https://chaintoken.com/token-metadata.json")))

;; Token Transfer
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
        (try! (ft-transfer? chain-token amount sender recipient))
        (if (is-some memo)
            (begin 
                (print (unwrap! memo ERR_NOT_TOKEN_OWNER))
                true)
            true)
        (ok true)))

;; Admin Functions
(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (ft-mint? chain-token amount recipient)
    )
)

(define-public (set-token-uri (new-uri (string-utf8 256)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (ok true)
    )
)

;; Authorization for Vesting Contract
(define-public (authorize-contract (contract-principal principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (ok true)
    )
)

;; Read-only helper functions
(define-read-only (is-contract-owner (account principal))
    (is-eq account CONTRACT_OWNER))

(define-read-only (get-decimals-in-uint)
    (pow u10 (unwrap-panic (get-decimals))))