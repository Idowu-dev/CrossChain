;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-SCHEDULE (err u101))
(define-constant ERR-ALREADY-CLAIMED (err u103))
(define-constant ERR-CLIFF-NOT-REACHED (err u104))

;; Data variables
(define-data-var contract-owner principal tx-sender)

;; Data maps
(define-map vesting-schedules
    { beneficiary: principal, schedule-id: uint }
    {
        total-amount: uint,
        start-height: uint,
        cliff-length: uint,
        vesting-length: uint,
        claimed-amount: uint
    }
)

;; Calculate vested amount
(define-private (calculate-vested-amount 
    (schedule {
        total-amount: uint,
        start-height: uint,
        cliff-length: uint,
        vesting-length: uint,
        claimed-amount: uint
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

;; Transfer tokens (implementation would depend on specific token contract)
(define-private (transfer-tokens (amount uint) (recipient principal))
    (ok true)
)

;; Create new vesting schedule
(define-public (create-vesting-schedule 
    (beneficiary principal)
    (schedule-id uint)
    (total-amount uint)
    (cliff-length uint)
    (vesting-length uint))
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
                claimed-amount: u0
            }
        )
        (ok true)
    )
)

;; Claim vested tokens
(define-public (claim-tokens (schedule-id uint))
    (let (
        (schedule (unwrap! (map-get? vesting-schedules 
            { beneficiary: tx-sender, schedule-id: schedule-id })
            ERR-INVALID-SCHEDULE))
        (vested-amount (calculate-vested-amount schedule))
        (claimable-amount (- vested-amount (get claimed-amount schedule)))
    )
        (asserts! (>= block-height (+ (get start-height schedule) 
                                    (get cliff-length schedule)))
                 ERR-CLIFF-NOT-REACHED)
        (asserts! (> claimable-amount u0) ERR-ALREADY-CLAIMED)
        
        ;; Update claimed amount
        (map-set vesting-schedules
            { beneficiary: tx-sender, schedule-id: schedule-id }
            (merge schedule { claimed-amount: vested-amount })
        )
        
        ;; Perform token transfer
        (transfer-tokens claimable-amount tx-sender)
    )
)

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