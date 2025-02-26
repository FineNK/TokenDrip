;; TokenDrip Distribution Contract
;; This contract handles token distribution with various safety checks and features

;; Define SIP-010 Fungible Token trait
(define-trait fungible-token-trait
    (
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))
        (get-name () (response (string-ascii 32) uint))
        (get-symbol () (response (string-ascii 32) uint))
        (get-decimals () (response uint uint))
        (get-balance (principal) (response uint uint))
        (get-total-supply () (response uint uint))
        (get-token-uri () (response (optional (string-utf8 256)) uint))
    )
)

;; Error Codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-ALREADY-RECEIVED (err u101))
(define-constant ERR-NOT-QUALIFIED (err u102))
(define-constant ERR-INCORRECT-AMOUNT (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-DISTRIBUTION-INACTIVE (err u105))
(define-constant ERR-TOKEN-UNDEFINED (err u106))
(define-constant ERR-UNRECOGNIZED-TOKEN (err u107))
(define-constant ERR-INVALID-QUANTITY (err u108))
(define-constant ERR-INVALID-TIMEFRAME (err u109))
(define-constant ERR-INVALID-RECIPIENT (err u110))

;; Constants for validation
(define-constant MAX-DISTRIBUTION-AMOUNT u1000000000)
(define-constant MIN-DISTRIBUTION-AMOUNT u1)
(define-constant MAX-DISTRIBUTION-TIMEFRAME u10000)
(define-constant CONTRACT-IDENTITY (as-contract tx-sender))

;; Data Variables
(define-data-var admin-principal principal tx-sender)
(define-data-var total-distribution-amount uint u0)
(define-data-var distribution-active bool true)
(define-data-var distribution-end-time uint u0)
(define-data-var tokens-per-distribution uint u0)
(define-data-var token-principal (optional principal) none)

;; Data Maps
(define-map qualified-recipients principal uint)
(define-map distributed-amounts principal uint)
(define-map approved-recipients principal bool)
(define-map supported-tokens principal bool)

;; Private validation functions
(define-private (validate-quantity (quantity uint))
    (and 
        (>= quantity MIN-DISTRIBUTION-AMOUNT)
        (<= quantity MAX-DISTRIBUTION-AMOUNT)
    )
)

(define-private (validate-timeframe (timeframe uint))
    (<= timeframe MAX-DISTRIBUTION-TIMEFRAME)
)

(define-private (validate-recipient (recipient principal))
    (and
        (not (is-eq recipient CONTRACT-IDENTITY))
        (not (is-eq recipient (var-get admin-principal)))
    )
)

(define-private (is-supported-token (token principal))
    (default-to false (map-get? supported-tokens token))
)

(define-private (validate-token-contract (token <fungible-token-trait>))
    (let ((token-address (contract-of token)))
        (and 
            (is-supported-token token-address)
            (match (contract-call? token get-name)
                success true
                error false)
        )
    )
)

;; Read-only functions
(define-read-only (get-distribution-status (recipient principal))
    (default-to u0 (map-get? distributed-amounts recipient))
)

(define-read-only (get-token-address)
    (var-get token-principal)
)

(define-read-only (is-qualified (recipient principal))
    (is-some (map-get? qualified-recipients recipient))
)

(define-read-only (get-admin)
    (var-get admin-principal)
)

(define-read-only (is-approved (recipient principal))
    (default-to false (map-get? approved-recipients recipient))
)

(define-read-only (get-distribution-info)
    (ok {
        total-amount: (var-get total-distribution-amount),
        is-active: (var-get distribution-active),
        end-time: (var-get distribution-end-time),
        amount-per-distribution: (var-get tokens-per-distribution)
    })
)

;; Private functions
(define-private (check-qualification (recipient principal))
    (and 
        (is-qualified recipient)
        (< (get-distribution-status recipient) (default-to u0 (map-get? qualified-recipients recipient)))
        (var-get distribution-active)
        (<= block-height (var-get distribution-end-time))
    )
)

;; Public functions
(define-public (set-token-address (token <fungible-token-trait>))
    (begin
        (asserts! (is-eq tx-sender (var-get admin-principal)) ERR-UNAUTHORIZED)
        (asserts! (match (contract-call? token get-name)
                    success true
                    error false) ERR-UNRECOGNIZED-TOKEN)
        (let ((token-address (contract-of token)))
            (map-set supported-tokens token-address true)
            (var-set token-principal (some token-address))
            (ok true)
        )
    )
)

(define-public (initialize-distribution (total-quantity uint) (per-distribution uint) (timeframe uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin-principal)) ERR-UNAUTHORIZED)
        (asserts! (validate-quantity total-quantity) ERR-INVALID-QUANTITY)
        (asserts! (validate-quantity per-distribution) ERR-INVALID-QUANTITY)
        (asserts! (validate-timeframe timeframe) ERR-INVALID-TIMEFRAME)
        (asserts! (>= total-quantity per-distribution) ERR-INVALID-QUANTITY)
        
        (var-set total-distribution-amount total-quantity)
        (var-set tokens-per-distribution per-distribution)
        (var-set distribution-end-time (+ block-height timeframe))
        (var-set distribution-active true)
        (ok true)
    )
)

(define-public (add-to-approved-list (recipient principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin-principal)) ERR-UNAUTHORIZED)
        (asserts! (validate-recipient recipient) ERR-INVALID-RECIPIENT)
        (asserts! (not (is-approved recipient)) ERR-ALREADY-RECEIVED)
        (map-set approved-recipients recipient true)
        (ok true)
    )
)

(define-public (remove-from-approved-list (recipient principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin-principal)) ERR-UNAUTHORIZED)
        (asserts! (validate-recipient recipient) ERR-INVALID-RECIPIENT)
        (asserts! (is-approved recipient) ERR-NOT-QUALIFIED)
        (map-delete approved-recipients recipient)
        (ok true)
    )
)

(define-public (set-qualified-amount (recipient principal) (quantity uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin-principal)) ERR-UNAUTHORIZED)
        (asserts! (validate-recipient recipient) ERR-INVALID-RECIPIENT)
        (asserts! (validate-quantity quantity) ERR-INVALID-QUANTITY)
        (map-set qualified-recipients recipient quantity)
        (ok true)
    )
)

(define-public (receive-distribution (ft <fungible-token-trait>))
    (let (
        (recipient tx-sender)
        (qualified-amount (default-to u0 (map-get? qualified-recipients recipient)))
        (received-amount (get-distribution-status recipient))
        (token (unwrap! (var-get token-principal) ERR-TOKEN-UNDEFINED))
    )
        (asserts! (validate-recipient recipient) ERR-INVALID-RECIPIENT)
        (asserts! (validate-token-contract ft) ERR-UNRECOGNIZED-TOKEN)
        (asserts! (is-eq token (contract-of ft)) ERR-UNRECOGNIZED-TOKEN)
        (asserts! (check-qualification recipient) ERR-NOT-QUALIFIED)
        (asserts! (>= (- qualified-amount received-amount) (var-get tokens-per-distribution)) ERR-INSUFFICIENT-FUNDS)
        
        ;; Update received amount
        (map-set distributed-amounts recipient (+ received-amount (var-get tokens-per-distribution)))
        
        ;; Transfer tokens using fungible-token-trait
        (as-contract
            (contract-call? ft transfer
                (var-get tokens-per-distribution)
                tx-sender
                recipient
                none
            )
        )
    )
)

(define-public (end-distribution)
    (begin
        (asserts! (is-eq tx-sender (var-get admin-principal)) ERR-UNAUTHORIZED)
        (var-set distribution-active false)
        (ok true)
    )
)

;; Emergency functions
(define-public (update-distribution-timeframe (new-end uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin-principal)) ERR-UNAUTHORIZED)
        (asserts! (validate-timeframe (- new-end block-height)) ERR-INVALID-TIMEFRAME)
        (var-set distribution-end-time new-end)
        (ok true)
    )
)

(define-public (emergency-token-recovery (ft <fungible-token-trait>) (quantity uint))
    (let ((token (unwrap! (var-get token-principal) ERR-TOKEN-UNDEFINED)))
        (asserts! (is-eq tx-sender (var-get admin-principal)) ERR-UNAUTHORIZED)
        (asserts! (validate-quantity quantity) ERR-INVALID-QUANTITY)
        (asserts! (validate-token-contract ft) ERR-UNRECOGNIZED-TOKEN)
        (asserts! (is-eq (contract-of ft) token) ERR-UNRECOGNIZED-TOKEN)
        (as-contract
            (contract-call? ft transfer
                quantity
                tx-sender
                (var-get admin-principal)
                none
            )
        )
    )
)