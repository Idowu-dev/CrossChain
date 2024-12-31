(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-SCHEDULE (err u101))
(define-constant ERR-INVALID-PROOF (err u102))
(define-constant ERR-ALREADY-CLAIMED (err u103))
(define-constant ERR-CLIFF-NOT-REACHED (err u104))
(define-constant ERR-INVALID-DELEGATION (err u105))
(define-constant ERR-CHAIN-NOT-SUPPORTED (err u106))

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var merkle-root (buff 32) 0x)
;; Oracle contract details
(define-constant ORACLE_ADDRESS 'SP000000000000000000002Q6VF78)
(define-constant ORACLE_CONTRACT 'cross-chain-oracle)

;; Data maps
(define-map vesting-schedules
    { beneficiary: principal, schedule-id: uint }
    {
        total-amount: uint,
        start-height: uint,
        cliff-length: uint,
        vesting-length: uint,
        claimed-amount: uint,
        chain-id: uint,
        delegated-to: (optional principal)
    }
)

(define-map cross-chain-claims
    { chain-id: uint, claim-id: (buff 32) }
    { processed: bool }
)

(define-map governance-snapshots
    { block-height: uint }
    { total-vested: uint, participants: (list 200 principal) }
)

;; Public functions

;; Create new vesting schedule
(define-public (create-vesting-schedule 
    (beneficiary principal)
    (schedule-id uint)
    (total-amount uint)
    (cliff-length uint)
    (vesting-length uint)
    (chain-id uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (> vesting-length cliff-length) ERR-INVALID-SCHEDULE)
        (map-set vesting-schedules
            { beneficiary: beneficiary, schedule-id: schedule-id }
            {
                total-amount: total-amount,
                start-height: block-height,
                cliff-length: cliff-length,
                vesting-length: vesting-length,
                claimed-amount: u0,
                chain-id: chain-id,
                delegated-to: none
            }
        )
        (ok true)
    )
)

;; Claim vested tokens
(define-public (claim-tokens 
    (schedule-id uint)
    (proof (buff 32)))
    (let (
        (schedule (unwrap! (map-get? vesting-schedules 
            { beneficiary: tx-sender, schedule-id: schedule-id })
            ERR-INVALID-SCHEDULE))
        (claimable-amount (get-claimable-amount tx-sender schedule-id))
    )
        (asserts! (is-valid-proof proof) ERR-INVALID-PROOF)
        (asserts! (> claimable-amount u0) ERR-ALREADY-CLAIMED)
        (asserts! (>= block-height (+ (get start-height schedule) 
                                    (get cliff-length schedule)))
                 ERR-CLIFF-NOT-REACHED)
        
        ;; Update claimed amount
        (map-set vesting-schedules
            { beneficiary: tx-sender, schedule-id: schedule-id }
            (merge schedule { claimed-amount: (+ (get claimed-amount schedule) 
                                               claimable-amount) })
        )
        
        ;; Perform token transfer
        (as-contract (transfer-tokens claimable-amount tx-sender))
    )
)

;; Delegate claim rights
(define-public (delegate-rights 
    (schedule-id uint)
    (delegate-to principal))
    (let (
        (schedule (unwrap! (map-get? vesting-schedules 
            { beneficiary: tx-sender, schedule-id: schedule-id })
            ERR-INVALID-SCHEDULE))
    )
        (asserts! (is-none (get delegated-to schedule)) ERR-INVALID-DELEGATION)
        (map-set vesting-schedules
            { beneficiary: tx-sender, schedule-id: schedule-id }
            (merge schedule { delegated-to: (some delegate-to) })
        )
        (ok true)
    )
)

;; Process cross-chain claim
(define-public (process-cross-chain-claim
    (chain-id uint)
    (claim-id (buff 32))
    (proof (buff 32)))
    (let (
        (claim-status (default-to 
            { processed: false }
            (map-get? cross-chain-claims { chain-id: chain-id, claim-id: claim-id })))
    )
        (asserts! (not (get processed claim-status)) ERR-ALREADY-CLAIMED)
        (asserts! (is-valid-cross-chain-proof chain-id claim-id proof) ERR-INVALID-PROOF)
        
        ;; Mark claim as processed
        (map-set cross-chain-claims
            { chain-id: chain-id, claim-id: claim-id }
            { processed: true }
        )
        (ok true)
    )
)

;; Create governance snapshot
(define-public (create-governance-snapshot)
    (let (
        (current-height block-height)
        (participants (get-active-participants))
        (total-vested (fold + (map get-total-vested participants) u0))
    )
        (map-set governance-snapshots
            { block-height: current-height }
            { 
                total-vested: total-vested,
                participants: participants
            }
        )
        (ok true)
    )
)

;; Read-only functions

;; Get claimable amount
(define-read-only (get-claimable-amount (beneficiary principal) (schedule-id uint))
    (let (
        (schedule (unwrap! (map-get? vesting-schedules 
            { beneficiary: beneficiary, schedule-id: schedule-id })
            u0))
    )
        (if (>= block-height (+ (get start-height schedule) 
                               (get cliff-length schedule)))
            (- (calculate-vested-amount schedule) (get claimed-amount schedule))
            u0
        )
    )
)

;; Calculate vested amount
(define-read-only (calculate-vested-amount (schedule {
        total-amount: uint,
        start-height: uint,
        cliff-length: uint,
        vesting-length: uint,
        claimed-amount: uint,
        chain-id: uint,
        delegated-to: (optional principal)
    }))
    (let (
        (elapsed (- block-height (get start-height schedule)))
        (vesting-duration (get vesting-length schedule))
    )
        (if (>= elapsed vesting-duration)
            (get total-amount schedule)
            (/ (* (get total-amount schedule) elapsed) vesting-duration)
        )
    )
)

;; Private functions

;; Verify merkle proof
(define-private (is-valid-proof (proof (buff 32)))
    (is-eq (var-get merkle-root) 
           (hash160 proof))
)

;; Verify cross-chain proof
(define-private (is-valid-cross-chain-proof 
    (chain-id uint)
    (claim-id (buff 32))
    (proof (buff 32)))
    (contract-call? ORACLE_ADDRESS ORACLE_CONTRACT verify-proof chain-id claim-id proof)
)

;; Get active participants
(define-private (get-active-participants)
    (filter has-active-schedule (map-keys vesting-schedules))
)

;; Check if schedule is active
(define-private (has-active-schedule (schedule-key { beneficiary: principal, schedule-id: uint }))
    (match (map-get? vesting-schedules schedule-key)
        schedule (< (get claimed-amount schedule) (get total-amount schedule))
        false
    )
)

;; Get total vested tokens for a participant
(define-private (get-total-vested (schedule-key { beneficiary: principal, schedule-id: uint }))
    (match (map-get? vesting-schedules schedule-key)
        schedule (calculate-vested-amount schedule)
        u0
    )
)

;; Transfer tokens (implementation would depend on specific token contract)
(define-private (transfer-tokens (amount uint) (recipient principal))
    (ok true)
)