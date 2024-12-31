# Token Vesting Smart Contract

This smart contract enables the creation and management of token vesting schedules with the following features:
- Linear vesting over time
- Configurable cliff periods
- Multiple vesting schedules per beneficiary
- Secure claiming mechanism
- Real-time claimable amount calculation

## Contract Parameters

### Constants
- `MIN_VESTING_LENGTH`: 1 block (minimum vesting duration)
- `MAX_VESTING_LENGTH`: 525,600 blocks (approximately one year)
- `MIN_AMOUNT`: 1 token (minimum vesting amount)
- `MAX_AMOUNT`: 100,000,000,000 tokens (maximum vesting amount)
- `MAX_SCHEDULE_ID`: 1,000 (maximum number of schedule IDs)

### Error Codes
- `ERR-NOT-AUTHORIZED (u100)`: Caller is not authorized
- `ERR-INVALID-SCHEDULE (u101)`: Invalid schedule parameters
- `ERR-ALREADY-CLAIMED (u103)`: Tokens already claimed
- `ERR-CLIFF-NOT-REACHED (u104)`: Cliff period not reached
- `ERR-INVALID-BENEFICIARY (u105)`: Invalid beneficiary address
- `ERR-INVALID-AMOUNT (u106)`: Invalid token amount
- `ERR-INVALID-LENGTH (u107)`: Invalid vesting length
- `ERR-SCHEDULE-EXISTS (u108)`: Schedule already exists

## Functions

### Public Functions

#### create-vesting-schedule
Creates a new vesting schedule for a beneficiary.
```clarity
(create-vesting-schedule 
    (beneficiary principal)
    (schedule-id uint)
    (total-amount uint)
    (cliff-length uint)
    (vesting-length uint))
```

#### claim-tokens
Claims available vested tokens for a specific schedule.
```clarity
(claim-tokens (schedule-id uint))
```

#### get-claimable-amount
Returns the current claimable amount for a beneficiary's schedule.
```clarity
(get-claimable-amount (beneficiary principal) (schedule-id uint))
```

### Validation Rules
- Beneficiary cannot be the contract owner
- Total amount must be between MIN_AMOUNT and MAX_AMOUNT
- Vesting length must be between MIN_VESTING_LENGTH and MAX_VESTING_LENGTH
- Vesting length must be greater than cliff length
- Schedule ID must be between 0 and MAX_SCHEDULE_ID
- Schedule must not already exist for the given beneficiary and ID

## Usage Example

1. Create a vesting schedule:
```clarity
(contract-call? .token-vesting create-vesting-schedule
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; beneficiary
    u1                                           ;; schedule-id
    u1000000                                     ;; total-amount
    u5000                                        ;; cliff-length (in blocks)
    u50000                                       ;; vesting-length (in blocks)
)
```

2. Check claimable amount:
```clarity
(contract-call? .token-vesting get-claimable-amount
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; beneficiary
    u1                                           ;; schedule-id
)
```

3. Claim vested tokens:
```clarity
(contract-call? .token-vesting claim-tokens u1)  ;; schedule-id
```

## Implementation Notes

- Token transfers are currently mocked (returns ok true)
- Schedule creation is restricted to contract owner
- Vesting calculation is linear over the vesting period
- All amounts are handled in micro-units (multiply token amounts by 1,000,000)
- Block heights are used for time calculations

## Security Considerations

- Only the contract owner can create vesting schedules
- Input validation for all parameters
- Cliff period enforcement
- Prevention of duplicate schedules
- Safe arithmetic operations

## Development and Testing

To deploy and test this contract:
1. Deploy the contract to your Stacks network
2. Update the token transfer implementation for your specific token
3. Test all functions with various parameters
4. Verify vesting calculations match expected outcomes