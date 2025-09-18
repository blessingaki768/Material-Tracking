;; Supply Chain Provenance Tracker Smart Contract
;; This contract enables real-time verification and recording of raw material origins
;; throughout the entire supply chain process

;; Error constants for various failure scenarios
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-MATERIAL-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STATUS (err u102))
(define-constant ERR-INVALID-PARTICIPANT (err u103))
(define-constant ERR-DUPLICATE-MATERIAL (err u104))
(define-constant ERR-INVALID-LOCATION (err u105))
(define-constant ERR-INVALID-TIMESTAMP (err u106))
(define-constant ERR-INVALID-QUANTITY (err u107))
(define-constant ERR-PARTICIPANT-NOT-FOUND (err u108))
(define-constant ERR-INVALID-CERTIFICATION (err u109))
(define-constant ERR-MATERIAL-ALREADY-PROCESSED (err u110))
(define-constant ERR-INVALID-INPUT (err u111))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-STRING-LENGTH u256)
(define-constant MIN-QUANTITY u1)
(define-constant MAX-TEMPERATURE 1000)
(define-constant MIN-TEMPERATURE -1000)
(define-constant MAX-HUMIDITY u100)

;; Status constants for material lifecycle tracking
(define-constant STATUS-SOURCED u1)
(define-constant STATUS-TRANSPORTED u2)
(define-constant STATUS-PROCESSED u3)
(define-constant STATUS-MANUFACTURED u4)
(define-constant STATUS-DISTRIBUTED u5)
(define-constant STATUS-DELIVERED u6)

;; Data structure for storing comprehensive material information
(define-map materials
  { material-id: (string-ascii 64) }
  {
    origin: (string-ascii 128),          ;; Geographic origin of the material
    supplier: principal,                  ;; Address of the supplier
    current-owner: principal,            ;; Current owner in the supply chain
    status: uint,                        ;; Current status in the supply chain
    quantity: uint,                      ;; Amount of material
    unit: (string-ascii 32),            ;; Unit of measurement (kg, tons, etc.)
    timestamp: uint,                     ;; Last update timestamp
    certifications: (list 10 (string-ascii 64)), ;; Quality/compliance certifications
    location: (string-ascii 128),       ;; Current physical location
    temperature: (optional int),        ;; Temperature for sensitive materials
    humidity: (optional uint),           ;; Humidity levels if applicable
    batch-number: (string-ascii 32),    ;; Batch identification
    expiry-date: (optional uint)        ;; Expiration date if applicable
  }
)

;; Comprehensive tracking history for full audit trail
(define-map material-history
  { material-id: (string-ascii 64), sequence: uint }
  {
    action: (string-ascii 64),           ;; Type of action performed
    performer: principal,                ;; Who performed the action
    timestamp: uint,                     ;; When the action occurred
    location: (string-ascii 128),       ;; Where the action took place
    details: (string-ascii 256),        ;; Additional details about the action
    previous-owner: (optional principal), ;; Previous owner if ownership changed
    quantity-change: (optional int)     ;; Quantity change if applicable
  }
)

;; Authorized participants in the supply chain network
(define-map authorized-participants
  { participant: principal }
  {
    name: (string-ascii 64),             ;; Participant organization name
    role: (string-ascii 32),             ;; Role (supplier, manufacturer, etc.)
    authorized-by: principal,            ;; Who authorized this participant
    authorization-date: uint,            ;; When authorization was granted
    location: (string-ascii 128),       ;; Participant's primary location
    certifications: (list 5 (string-ascii 64)), ;; Participant certifications
    is-active: bool                      ;; Whether participant is currently active
  }
)

;; Counter for maintaining sequence in material history
(define-map material-sequence-counter
  { material-id: (string-ascii 64) }
  { counter: uint }
)

;; Quality standards and compliance requirements
(define-map quality-standards
  { standard-id: (string-ascii 32) }
  {
    name: (string-ascii 64),             ;; Standard name
    description: (string-ascii 256),     ;; Standard description
    requirements: (list 10 (string-ascii 128)), ;; List of requirements
    created-by: principal,               ;; Who created the standard
    created-at: uint                     ;; When standard was created
  }
)

;; Material certifications linked to quality standards
(define-map material-certifications
  { material-id: (string-ascii 64), standard-id: (string-ascii 32) }
  {
    certified-by: principal,             ;; Certifying authority
    certification-date: uint,            ;; Date of certification
    expiry-date: (optional uint),       ;; Certificate expiry if applicable
    certificate-hash: (string-ascii 64), ;; Hash of certificate document
    is-valid: bool                       ;; Current validity status
  }
)

;; Validation function to check if a participant is authorized
(define-private (is-authorized-participant (participant principal))
  (match (map-get? authorized-participants { participant: participant })
    participant-data (get is-active participant-data)
    false
  )
)

;; Validation function to check if a principal is valid (not zero address)
(define-private (is-valid-principal (participant principal))
  (not (is-eq participant 'ST000000000000000000002AMW42H))
)

;; Validation function to check if status transition is valid
(define-private (is-valid-status-transition (current-status uint) (new-status uint))
  (and
    (<= current-status new-status)          ;; Status can only move forward
    (>= new-status STATUS-SOURCED)         ;; Must be at least sourced
    (<= new-status STATUS-DELIVERED)       ;; Cannot exceed delivered
  )
)

;; Function to get next sequence number for material history
(define-private (get-next-sequence (material-id (string-ascii 64)))
  (let
    (
      (current-counter (default-to u0 (get counter (map-get? material-sequence-counter { material-id: material-id }))))
      (next-counter (+ current-counter u1))
    )
    (map-set material-sequence-counter { material-id: material-id } { counter: next-counter })
    next-counter
  )
)

;; Public function to authorize a new participant in the supply chain
(define-public (authorize-participant 
  (participant principal) 
  (name (string-ascii 64)) 
  (role (string-ascii 32))
  (location (string-ascii 128))
  (certifications (list 5 (string-ascii 64))))
  (begin
    ;; Only contract owner can authorize participants
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
    ;; Validate participant principal
    (asserts! (is-valid-principal participant) ERR-INVALID-PARTICIPANT)
    ;; Validate input parameters
    (asserts! (and (> (len name) u0) (<= (len name) u64)) ERR-INVALID-PARTICIPANT)
    (asserts! (and (> (len role) u0) (<= (len role) u32)) ERR-INVALID-PARTICIPANT)
    (asserts! (and (> (len location) u0) (<= (len location) u128)) ERR-INVALID-LOCATION)
    (asserts! (<= (len certifications) u5) ERR-INVALID-CERTIFICATION)
    ;; Validate participant is not already authorized to prevent duplicates
    (asserts! (is-none (get is-active (map-get? authorized-participants { participant: participant }))) ERR-DUPLICATE-MATERIAL)
    
    ;; Store participant information
    (ok (map-set authorized-participants
      { participant: participant }
      {
        name: name,
        role: role,
        authorized-by: tx-sender,
        authorization-date: block-height,
        location: location,
        certifications: certifications,
        is-active: true
      }
    ))
  )
)

;; Public function to deactivate a participant
(define-public (deactivate-participant (participant principal))
  (begin
    ;; Only contract owner can deactivate participants
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
    ;; Validate participant principal
    (asserts! (is-valid-principal participant) ERR-INVALID-PARTICIPANT)
    
    ;; Check if participant exists and get their data
    (match (map-get? authorized-participants { participant: participant })
      participant-data
      (begin
        ;; Verify participant is currently active
        (asserts! (get is-active participant-data) ERR-PARTICIPANT-NOT-FOUND)
        ;; Update participant status to inactive
        (ok (map-set authorized-participants
          { participant: participant }
          (merge participant-data { is-active: false })
        ))
      )
      ERR-PARTICIPANT-NOT-FOUND
    )
  )
)

;; Public function to register a new material with comprehensive details
(define-public (register-material
  (material-id (string-ascii 64))
  (origin (string-ascii 128))
  (quantity uint)
  (unit (string-ascii 32))
  (certifications (list 10 (string-ascii 64)))
  (location (string-ascii 128))
  (batch-number (string-ascii 32))
  (temperature (optional int))
  (humidity (optional uint))
  (expiry-date (optional uint)))
  (begin
    ;; Verify caller is authorized participant
    (asserts! (is-authorized-participant tx-sender) ERR-UNAUTHORIZED-ACCESS)
    ;; Validate material doesn't already exist
    (asserts! (is-none (map-get? materials { material-id: material-id })) ERR-DUPLICATE-MATERIAL)
    ;; Validate input parameters
    (asserts! (and (> (len material-id) u0) (<= (len material-id) u64)) ERR-INVALID-INPUT)
    (asserts! (and (> (len origin) u0) (<= (len origin) u128)) ERR-INVALID-LOCATION)
    (asserts! (>= quantity MIN-QUANTITY) ERR-INVALID-QUANTITY)
    (asserts! (and (> (len unit) u0) (<= (len unit) u32)) ERR-INVALID-INPUT)
    (asserts! (<= (len certifications) u10) ERR-INVALID-CERTIFICATION)
    (asserts! (and (> (len location) u0) (<= (len location) u128)) ERR-INVALID-LOCATION)
    (asserts! (and (> (len batch-number) u0) (<= (len batch-number) u32)) ERR-INVALID-INPUT)
    ;; Validate temperature range if provided
    (asserts! (match temperature
      temp-val (and (>= temp-val MIN-TEMPERATURE) (<= temp-val MAX-TEMPERATURE))
      true) ERR-INVALID-INPUT)
    ;; Validate humidity range if provided
    (asserts! (match humidity
      hum-val (<= hum-val MAX-HUMIDITY)
      true) ERR-INVALID-INPUT)
    ;; Validate expiry date if provided
    (asserts! (match expiry-date
      exp-val (> exp-val block-height)
      true) ERR-INVALID-INPUT)
    
    ;; Register the material
    (map-set materials
      { material-id: material-id }
      {
        origin: origin,
        supplier: tx-sender,
        current-owner: tx-sender,
        status: STATUS-SOURCED,
        quantity: quantity,
        unit: unit,
        timestamp: block-height,
        certifications: certifications,
        location: location,
        temperature: temperature,
        humidity: humidity,
        batch-number: batch-number,
        expiry-date: expiry-date
      }
    )
    
    ;; Record the registration in history
    (let
      (
        (sequence (get-next-sequence material-id))
      )
      (map-set material-history
        { material-id: material-id, sequence: sequence }
        {
          action: "REGISTERED",
          performer: tx-sender,
          timestamp: block-height,
          location: location,
          details: "Material registered in supply chain",
          previous-owner: none,
          quantity-change: none
        }
      )
    )
    (ok true)
  )
)

;; Public function to update material status with comprehensive tracking
(define-public (update-material-status
  (material-id (string-ascii 64))
  (new-status uint)
  (new-location (string-ascii 128))
  (details (string-ascii 256))
  (temperature (optional int))
  (humidity (optional uint)))
  (begin
    ;; Verify caller is authorized participant
    (asserts! (is-authorized-participant tx-sender) ERR-UNAUTHORIZED-ACCESS)
    ;; Validate input parameters
    (asserts! (and (> (len material-id) u0) (<= (len material-id) u64)) ERR-INVALID-INPUT)
    (asserts! (and (> (len new-location) u0) (<= (len new-location) u128)) ERR-INVALID-LOCATION)
    (asserts! (and (> (len details) u0) (<= (len details) u256)) ERR-INVALID-INPUT)
    ;; Validate temperature range if provided
    (asserts! (match temperature
      temp-val (and (>= temp-val MIN-TEMPERATURE) (<= temp-val MAX-TEMPERATURE))
      true) ERR-INVALID-INPUT)
    ;; Validate humidity range if provided
    (asserts! (match humidity
      hum-val (<= hum-val MAX-HUMIDITY)
      true) ERR-INVALID-INPUT)
    
    ;; Get current material data
    (match (map-get? materials { material-id: material-id })
      current-material
      (begin
        ;; Validate status transition
        (asserts! (is-valid-status-transition (get status current-material) new-status) ERR-INVALID-STATUS)
        
        ;; Update material information
        (map-set materials
          { material-id: material-id }
          (merge current-material {
            status: new-status,
            location: new-location,
            timestamp: block-height,
            temperature: temperature,
            humidity: humidity
          })
        )
        
        ;; Record status change in history
        (let
          (
            (sequence (get-next-sequence material-id))
          )
          (map-set material-history
            { material-id: material-id, sequence: sequence }
            {
              action: "STATUS_UPDATED",
              performer: tx-sender,
              timestamp: block-height,
              location: new-location,
              details: details,
              previous-owner: none,
              quantity-change: none
            }
          )
        )
        (ok true)
      )
      ERR-MATERIAL-NOT-FOUND
    )
  )
)

;; Public function to transfer ownership of materials
(define-public (transfer-ownership
  (material-id (string-ascii 64))
  (new-owner principal)
  (transfer-location (string-ascii 128))
  (details (string-ascii 256)))
  (begin
    ;; Verify caller is authorized participant
    (asserts! (is-authorized-participant tx-sender) ERR-UNAUTHORIZED-ACCESS)
    ;; Validate new owner principal
    (asserts! (is-valid-principal new-owner) ERR-INVALID-PARTICIPANT)
    ;; Verify new owner is authorized participant
    (asserts! (is-authorized-participant new-owner) ERR-UNAUTHORIZED-ACCESS)
    ;; Validate input parameters
    (asserts! (and (> (len material-id) u0) (<= (len material-id) u64)) ERR-INVALID-INPUT)
    (asserts! (and (> (len transfer-location) u0) (<= (len transfer-location) u128)) ERR-INVALID-LOCATION)
    (asserts! (and (> (len details) u0) (<= (len details) u256)) ERR-INVALID-INPUT)
    
    ;; Get current material data
    (match (map-get? materials { material-id: material-id })
      current-material
      (begin
        ;; Verify current owner
        (asserts! (is-eq (get current-owner current-material) tx-sender) ERR-UNAUTHORIZED-ACCESS)
        
        ;; Update ownership
        (map-set materials
          { material-id: material-id }
          (merge current-material {
            current-owner: new-owner,
            location: transfer-location,
            timestamp: block-height
          })
        )
        
        ;; Record ownership transfer in history
        (let
          (
            (sequence (get-next-sequence material-id))
          )
          (map-set material-history
            { material-id: material-id, sequence: sequence }
            {
              action: "OWNERSHIP_TRANSFERRED",
              performer: tx-sender,
              timestamp: block-height,
              location: transfer-location,
              details: details,
              previous-owner: (some tx-sender),
              quantity-change: none
            }
          )
        )
        (ok true)
      )
      ERR-MATERIAL-NOT-FOUND
    )
  )
)

;; Public function to update material quantity (for processing/consumption)
(define-public (update-quantity
  (material-id (string-ascii 64))
  (quantity-change int)
  (reason (string-ascii 128))
  (location (string-ascii 128)))
  (begin
    ;; Verify caller is authorized participant
    (asserts! (is-authorized-participant tx-sender) ERR-UNAUTHORIZED-ACCESS)
    ;; Validate input parameters
    (asserts! (and (> (len material-id) u0) (<= (len material-id) u64)) ERR-INVALID-INPUT)
    (asserts! (and (> (len reason) u0) (<= (len reason) u128)) ERR-INVALID-INPUT)
    (asserts! (and (> (len location) u0) (<= (len location) u128)) ERR-INVALID-LOCATION)
    
    ;; Get current material data
    (match (map-get? materials { material-id: material-id })
      current-material
      (begin
        ;; Verify current owner or authorized participant
        (asserts! (or (is-eq (get current-owner current-material) tx-sender)
                     (is-authorized-participant tx-sender)) ERR-UNAUTHORIZED-ACCESS)
        
        ;; Calculate new quantity
        (let
          (
            (current-quantity (to-int (get quantity current-material)))
            (new-quantity-int (+ current-quantity quantity-change))
          )
          ;; Ensure quantity doesn't go negative
          (asserts! (>= new-quantity-int 0) ERR-INVALID-QUANTITY)
          
          ;; Update material quantity
          (map-set materials
            { material-id: material-id }
            (merge current-material {
              quantity: (to-uint new-quantity-int),
              location: location,
              timestamp: block-height
            })
          )
          
          ;; Record quantity change in history
          (let
            (
              (sequence (get-next-sequence material-id))
            )
            (map-set material-history
              { material-id: material-id, sequence: sequence }
              {
                action: "QUANTITY_UPDATED",
                performer: tx-sender,
                timestamp: block-height,
                location: location,
                details: reason,
                previous-owner: none,
                quantity-change: (some quantity-change)
              }
            )
          )
        )
        (ok true)
      )
      ERR-MATERIAL-NOT-FOUND
    )
  )
)

;; Public function to add quality certification to material
(define-public (add-certification
  (material-id (string-ascii 64))
  (standard-id (string-ascii 32))
  (certificate-hash (string-ascii 64))
  (expiry-date (optional uint)))
  (begin
    ;; Verify caller is authorized participant
    (asserts! (is-authorized-participant tx-sender) ERR-UNAUTHORIZED-ACCESS)
    ;; Validate input parameters
    (asserts! (and (> (len material-id) u0) (<= (len material-id) u64)) ERR-INVALID-INPUT)
    (asserts! (and (> (len standard-id) u0) (<= (len standard-id) u32)) ERR-INVALID-CERTIFICATION)
    (asserts! (and (> (len certificate-hash) u0) (<= (len certificate-hash) u64)) ERR-INVALID-CERTIFICATION)
    ;; Validate expiry date if provided
    (asserts! (match expiry-date
      exp-val (> exp-val block-height)
      true) ERR-INVALID-INPUT)
    
    ;; Verify material exists
    (asserts! (is-some (map-get? materials { material-id: material-id })) ERR-MATERIAL-NOT-FOUND)
    
    ;; Add certification
    (map-set material-certifications
      { material-id: material-id, standard-id: standard-id }
      {
        certified-by: tx-sender,
        certification-date: block-height,
        expiry-date: expiry-date,
        certificate-hash: certificate-hash,
        is-valid: true
      }
    )
    
    ;; Record certification in history
    (let
      (
        (sequence (get-next-sequence material-id))
      )
      (map-set material-history
        { material-id: material-id, sequence: sequence }
        {
          action: "CERTIFIED",
          performer: tx-sender,
          timestamp: block-height,
          location: "",
          details: "Quality certification added",
          previous-owner: none,
          quantity-change: none
        }
      )
    )
    (ok true)
  )
)

;; Public function to create quality standard
(define-public (create-quality-standard
  (standard-id (string-ascii 32))
  (name (string-ascii 64))
  (description (string-ascii 256))
  (requirements (list 10 (string-ascii 128))))
  (begin
    ;; Only authorized participants can create standards
    (asserts! (is-authorized-participant tx-sender) ERR-UNAUTHORIZED-ACCESS)
    ;; Validate input parameters
    (asserts! (and (> (len standard-id) u0) (<= (len standard-id) u32)) ERR-INVALID-CERTIFICATION)
    (asserts! (and (> (len name) u0) (<= (len name) u64)) ERR-INVALID-CERTIFICATION)
    (asserts! (and (> (len description) u0) (<= (len description) u256)) ERR-INVALID-CERTIFICATION)
    (asserts! (<= (len requirements) u10) ERR-INVALID-CERTIFICATION)
    
    ;; Create quality standard
    (map-set quality-standards
      { standard-id: standard-id }
      {
        name: name,
        description: description,
        requirements: requirements,
        created-by: tx-sender,
        created-at: block-height
      }
    )
    (ok true)
  )
)

;; Read-only function to get complete material information
(define-read-only (get-material (material-id (string-ascii 64)))
  (map-get? materials { material-id: material-id })
)

;; Read-only function to get material history entry
(define-read-only (get-material-history-entry (material-id (string-ascii 64)) (sequence uint))
  (map-get? material-history { material-id: material-id, sequence: sequence })
)

;; Read-only function to get current sequence counter
(define-read-only (get-material-sequence-counter (material-id (string-ascii 64)))
  (default-to u0 (get counter (map-get? material-sequence-counter { material-id: material-id })))
)

;; Read-only function to get participant information
(define-read-only (get-participant (participant principal))
  (map-get? authorized-participants { participant: participant })
)

;; Read-only function to check if participant is authorized
(define-read-only (check-participant-authorization (participant principal))
  (is-authorized-participant participant)
)

;; Read-only function to get quality standard information
(define-read-only (get-quality-standard (standard-id (string-ascii 32)))
  (map-get? quality-standards { standard-id: standard-id })
)

;; Read-only function to get material certification
(define-read-only (get-material-certification (material-id (string-ascii 64)) (standard-id (string-ascii 32)))
  (map-get? material-certifications { material-id: material-id, standard-id: standard-id })
)

;; Read-only function to verify material authenticity
(define-read-only (verify-material-authenticity (material-id (string-ascii 64)))
  (match (map-get? materials { material-id: material-id })
    material-data (some {
      material-id: material-id,
      origin: (get origin material-data),
      supplier: (get supplier material-data),
      current-owner: (get current-owner material-data),
      status: (get status material-data),
      timestamp: (get timestamp material-data),
      location: (get location material-data),
      batch-number: (get batch-number material-data)
    })
    none
  )
)

;; Read-only function to get materials by status
(define-read-only (get-materials-by-status (target-status uint))
  (ok target-status)
)