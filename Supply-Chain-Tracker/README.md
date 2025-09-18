# Supply Chain Provenance Tracker Smart Contract

## Overview

The Supply Chain Provenance Tracker is a comprehensive smart contract built for blockchain-based supply chain management. It enables real-time verification and recording of raw material origins throughout the entire supply chain process, from sourcing to final delivery.

## Features

### Core Functionality
- **Material Registration**: Register new materials with detailed provenance information
- **Status Tracking**: Track materials through six distinct lifecycle stages
- **Ownership Management**: Transfer ownership between authorized participants
- **Quantity Management**: Update material quantities for processing and consumption
- **Quality Certifications**: Add and manage quality standards and certifications
- **Complete Audit Trail**: Immutable history of all material transactions and changes

### Security Features
- **Authorization System**: Only authorized participants can interact with materials
- **Role-Based Access Control**: Different roles for suppliers, manufacturers, distributors
- **Input Validation**: Comprehensive validation of all input parameters
- **Ownership Verification**: Strict ownership checks for material transfers

## Smart Contract Structure

### Constants

#### Error Constants
- `ERR-UNAUTHORIZED-ACCESS (u100)`: Unauthorized participant access
- `ERR-MATERIAL-NOT-FOUND (u101)`: Material ID not found
- `ERR-INVALID-STATUS (u102)`: Invalid status transition
- `ERR-INVALID-PARTICIPANT (u103)`: Invalid participant data
- `ERR-DUPLICATE-MATERIAL (u104)`: Material already exists
- `ERR-INVALID-LOCATION (u105)`: Invalid location data
- `ERR-INVALID-TIMESTAMP (u106)`: Invalid timestamp
- `ERR-INVALID-QUANTITY (u107)`: Invalid quantity value
- `ERR-PARTICIPANT-NOT-FOUND (u108)`: Participant not found
- `ERR-INVALID-CERTIFICATION (u109)`: Invalid certification data
- `ERR-MATERIAL-ALREADY-PROCESSED (u110)`: Material already processed

#### Status Constants
- `STATUS-SOURCED (u1)`: Material sourced from origin
- `STATUS-TRANSPORTED (u2)`: Material in transit
- `STATUS-PROCESSED (u3)`: Material processed/refined
- `STATUS-MANUFACTURED (u4)`: Material manufactured into product
- `STATUS-DISTRIBUTED (u5)`: Product distributed to retailers
- `STATUS-DELIVERED (u6)`: Product delivered to end customer

## Data Structures

### Materials Map
Stores comprehensive information about each material:
```
{
  material-id: string-ascii 64,
  origin: string-ascii 128,
  supplier: principal,
  current-owner: principal,
  status: uint,
  quantity: uint,
  unit: string-ascii 32,
  timestamp: uint,
  certifications: list 10 string-ascii 64,
  location: string-ascii 128,
  temperature: optional int,
  humidity: optional uint,
  batch-number: string-ascii 32,
  expiry-date: optional uint
}
```

### Material History Map
Maintains complete audit trail:
```
{
  material-id: string-ascii 64,
  sequence: uint,
  action: string-ascii 64,
  performer: principal,
  timestamp: uint,
  location: string-ascii 128,
  details: string-ascii 256,
  previous-owner: optional principal,
  quantity-change: optional int
}
```

### Authorized Participants Map
Manages supply chain participants:
```
{
  participant: principal,
  name: string-ascii 64,
  role: string-ascii 32,
  authorized-by: principal,
  authorization-date: uint,
  location: string-ascii 128,
  certifications: list 5 string-ascii 64,
  is-active: bool
}
```

## Public Functions

### Participant Management

#### `authorize-participant`
Authorize a new participant in the supply chain network.
```
(authorize-participant participant name role location certifications)
```
- **Access**: Contract owner only
- **Parameters**: 
  - `participant`: Principal address
  - `name`: Organization name
  - `role`: Participant role
  - `location`: Primary location
  - `certifications`: List of certifications

#### `deactivate-participant`
Deactivate an existing participant.
```
(deactivate-participant participant)
```
- **Access**: Contract owner only
- **Parameters**: `participant`: Principal to deactivate

### Material Management

#### `register-material`
Register a new material in the supply chain.
```
(register-material material-id origin quantity unit certifications location batch-number temperature humidity expiry-date)
```
- **Access**: Authorized participants only
- **Parameters**:
  - `material-id`: Unique material identifier
  - `origin`: Geographic origin
  - `quantity`: Amount of material
  - `unit`: Unit of measurement
  - `certifications`: Quality certifications
  - `location`: Current location
  - `batch-number`: Batch identifier
  - `temperature`: Storage temperature (optional)
  - `humidity`: Humidity level (optional)
  - `expiry-date`: Expiration date (optional)

#### `update-material-status`
Update material status and location.
```
(update-material-status material-id new-status new-location details temperature humidity)
```
- **Access**: Authorized participants only
- **Parameters**:
  - `material-id`: Material to update
  - `new-status`: New status code
  - `new-location`: Updated location
  - `details`: Change description
  - `temperature`: Updated temperature (optional)
  - `humidity`: Updated humidity (optional)

#### `transfer-ownership`
Transfer material ownership between participants.
```
(transfer-ownership material-id new-owner transfer-location details)
```
- **Access**: Current owner only
- **Parameters**:
  - `material-id`: Material to transfer
  - `new-owner`: New owner principal
  - `transfer-location`: Transfer location
  - `details`: Transfer details

#### `update-quantity`
Update material quantity for processing or consumption.
```
(update-quantity material-id quantity-change reason location)
```
- **Access**: Material owner or authorized participants
- **Parameters**:
  - `material-id`: Material to update
  - `quantity-change`: Quantity change (positive/negative)
  - `reason`: Reason for change
  - `location`: Current location

### Quality Management

#### `add-certification`
Add quality certification to material.
```
(add-certification material-id standard-id certificate-hash expiry-date)
```
- **Access**: Authorized participants only
- **Parameters**:
  - `material-id`: Material to certify
  - `standard-id`: Quality standard identifier
  - `certificate-hash`: Certificate document hash
  - `expiry-date`: Certificate expiry (optional)

#### `create-quality-standard`
Create a new quality standard.
```
(create-quality-standard standard-id name description requirements)
```
- **Access**: Authorized participants only
- **Parameters**:
  - `standard-id`: Standard identifier
  - `name`: Standard name
  - `description`: Standard description
  - `requirements`: List of requirements

## Read-Only Functions

### Material Information
- `get-material`: Retrieve complete material information
- `get-material-history-entry`: Get specific history entry
- `get-material-sequence-counter`: Get current sequence number
- `verify-material-authenticity`: Verify material authenticity

### Participant Information
- `get-participant`: Retrieve participant information
- `check-participant-authorization`: Check if participant is authorized

### Quality Standards
- `get-quality-standard`: Retrieve quality standard information
- `get-material-certification`: Get material certification details

## Usage Examples

### 1. Authorizing a Participant
```clarity
(contract-call? .supply-chain-tracker authorize-participant
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  "Organic Farms Ltd"
  "supplier"
  "California, USA"
  (list "USDA-Organic" "Fair-Trade"))
```

### 2. Registering New Material
```clarity
(contract-call? .supply-chain-tracker register-material
  "ORG-WHEAT-001"
  "California Central Valley"
  u1000
  "kg"
  (list "USDA-Organic")
  "Farm Storage Facility A"
  "BATCH-2024-001"
  (some -2)
  (some u45)
  (some u1735689600))
```

### 3. Updating Material Status
```clarity
(contract-call? .supply-chain-tracker update-material-status
  "ORG-WHEAT-001"
  STATUS-TRANSPORTED
  "Distribution Center, Denver"
  "Material shipped to processing facility"
  (some 5)
  (some u40))
```

### 4. Transferring Ownership
```clarity
(contract-call? .supply-chain-tracker transfer-ownership
  "ORG-WHEAT-001"
  'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE
  "Processing Facility, Chicago"
  "Transfer to flour mill for processing")
```

## Security Considerations

### Access Control
- Only the contract owner can authorize/deactivate participants
- Only authorized participants can interact with materials
- Material owners have exclusive transfer rights
- Comprehensive input validation prevents invalid data

### Data Integrity
- Immutable history tracking prevents tampering
- Status transitions follow logical progression
- Quantity changes are tracked and validated
- Certificate hashes ensure document integrity

### Audit Trail
- Complete history of all material interactions
- Timestamped entries with performer identification
- Location tracking throughout supply chain
- Detailed action descriptions for transparency

## Deployment Instructions

1. **Prerequisites**
   - Stacks blockchain node access
   - Clarity development environment
   - Sufficient STX tokens for deployment

2. **Deployment Steps**
   ```bash
   clarinet deploy --network=testnet
   ```

3. **Initial Setup**
   - Deploy contract to blockchain
   - Authorize initial participants
   - Create basic quality standards
   - Configure participant roles

## Integration

### Frontend Integration
- Use Stacks.js library for blockchain interaction
- Implement participant dashboard for material tracking
- Create QR code generation for material identification
- Build real-time status monitoring interface

### API Integration
- Connect to existing ERP systems
- Integrate with IoT sensors for automated updates
- Link to certification authority databases
- Connect to logistics tracking systems