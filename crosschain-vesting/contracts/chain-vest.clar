;; Simple Token Vesting Contract
;; Implements basic vesting schedules

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-SCHEDULE (err u101))
(define-constant ERR-ALREADY-CLAIMED (err u103))
(define-constant ERR-CLIFF-NOT-REACHED (err u104))
(define-constant ERR-INVALID-BENEFICIARY (err u105))
(define-constant ERR-INVALID-AMOUNT (err u106))
(define-constant ERR-INVALID-LENGTH (err u107))
(define-constant ERR-SCHEDULE-EXISTS (err u108))

;; Constants for validation
(define-constant MIN_VESTING_LENGTH u1)
(define-constant MAX_VESTING_LENGTH u525600) ;; One year in blocks
(define-constant MIN_AMOUNT u1)
(define-constant MAX_AMOUNT u100000000000) ;; 100B tokens
(define-constant MAX_SCHEDULE_ID u1000)

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

;; Check schedule ID validity
(define-private (check-schedule-id (id uint))
    (and (>= id u0) (< id MAX_SCHEDULE_ID)))

;; Validate vesting schedule parameters
(define-private (validate-schedule-params 
    (beneficiary principal)
    (schedule-id uint)
    (total-amount uint)
    (cliff-length uint)
    (vesting-length uint))
    (begin
        (asserts! (not (is-eq beneficiary tx-sender)) ERR-INVALID-BENEFICIARY)
        (asserts! (and (>= total-amount MIN_AMOUNT) (<= total-amount MAX_AMOUNT)) ERR-INVALID-AMOUNT)
        (asserts! (and (>= vesting-length MIN_VESTING_LENGTH) (<= vesting-length MAX_VESTING_LENGTH)) ERR-INVALID-LENGTH)
        (asserts! (>= vesting-length cliff-length) ERR-INVALID-SCHEDULE)
        (asserts! (check-schedule-id schedule-id) ERR-INVALID-SCHEDULE)
        (asserts! (is-none (map-get? vesting-schedules 
            { beneficiary: beneficiary, schedule-id: schedule-id })) 
            ERR-SCHEDULE-EXISTS)
        (ok true)
    ))

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
        (try! (validate-schedule-params beneficiary schedule-id total-amount cliff-length vesting-length))
        
        (ok (map-set vesting-schedules
            { beneficiary: beneficiary, schedule-id: schedule-id }
            {
                total-amount: total-amount,
                start-height: block-height,
                cliff-length: cliff-length,
                vesting-length: vesting-length,
                claimed-amount: u0
            }))
    )
)

;; Claim vested tokens
(define-public (claim-tokens (schedule-id uint))
    (begin
        (asserts! (check-schedule-id schedule-id) ERR-INVALID-SCHEDULE)
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
)

;; Get claimable amount
(define-read-only (get-claimable-amount (beneficiary principal) (schedule-id uint))
    (begin
        (asserts! (check-schedule-id schedule-id) ERR-INVALID-SCHEDULE)
        (match (map-get? vesting-schedules 
            { beneficiary: beneficiary, schedule-id: schedule-id })
            schedule 
                (if (>= block-height (+ (get start-height schedule) 
                                      (get cliff-length schedule)))
                    (ok (- (calculate-vested-amount schedule) 
                          (get claimed-amount schedule)))
                    (ok u0))
            (err u0))
    ))