# Representation Management Sidekiq Jobs

This directory contains Sidekiq background jobs that handle the synchronization and updating of accredited entities (attorneys, agents, VSOs, and representatives) from the GCLAWS API to the local database.

## Overview

The synchronization process consists of two main jobs that work together:

1. **AccreditedEntitiesQueueUpdates** - Fetches and processes entity data from GCLAWS API
2. **AccreditedIndividualsUpdate** - Validates addresses and updates database records

## Jobs

### AccreditedEntitiesQueueUpdates

**Location:** `app/sidekiq/representation_management/accredited_entities_queue_updates.rb`

**Schedule:** Daily at 4:00 AM ET (cron: `0 4 * * *`)

This is the primary job that initiates the accredited entities update process. It performs the following tasks:

#### Key Features:
- Fetches accredited entities data from GCLAWS API (agents, attorneys, representatives, VSOs)
- Creates or updates `AccreditedIndividual` records for agents, attorneys, and representatives
- Creates or updates `AccreditedOrganization` records for VSOs
- Manages `Accreditation` join records between representatives and their VSOs
- Implements data validation to prevent large decreases in entity counts (configurable threshold)
- Queues address validation jobs for entities with changed addresses
- Removes records no longer present in the GCLAWS API
- Ensures data integrity by processing VSOs before representatives

#### Usage:
```ruby
# Process all entity types
RepresentationManagement::AccreditedEntitiesQueueUpdates.perform_async

# Force update specific entity types (bypasses count validation)
RepresentationManagement::AccreditedEntitiesQueueUpdates.perform_async(['agents'])
RepresentationManagement::AccreditedEntitiesQueueUpdates.perform_async(['agents', 'attorneys'])

# Representatives and VSOs MUST be processed together
RepresentationManagement::AccreditedEntitiesQueueUpdates.perform_async(['representatives', 'veteran_service_organizations'])
```

**Important**: Representatives and VSOs must always be processed together to maintain referential integrity. The system will enforce this requirement.

#### Configuration:
- **DECREASE_THRESHOLD**: Maximum allowed percentage decrease in entity counts before updates are blocked.  This is a negative percentage (e.g., -20 for 20% decrease).
- **SLICE_SIZE**: Number of records processed in each address validation batch (default: 30)

#### Process Flow:
1. Fetches current counts from GCLAWS API
2. Validates counts against stored historical data
3. For each entity type (if validation passes):
   - Fetches all pages of data from API
   - Creates/updates database records
   - Identifies records needing address validation
   - Queues validation jobs in batches
4. Special handling for VSOs and Representatives:
   - VSOs are always processed before representatives
   - Representative-VSO associations are tracked and stored
   - Accreditation join records are created/updated
5. Removes obsolete records (individuals, organizations, and accreditations)

### AccreditedIndividualsUpdate

**Location:** `app/sidekiq/representation_management/accredited_individuals_update.rb`

This job handles the address validation and final update of AccreditedIndividual records.

#### Key Features:
- Validates addresses using VAProfile Address Validation Service
- Implements retry logic for failed validations
- Handles P.O. Box addresses with special validation logic
- Updates records with validated address data and geocoding information
- Logs errors to Rails logger and Slack (production only)

#### Usage:
This job is automatically queued by `AccreditedEntitiesQueueUpdates` and should not be called directly.

```ruby
# Called internally with JSON data
RepresentationManagement::AccreditedIndividualsUpdate.perform_async(json_individuals)
```

#### Address Validation Logic:
1. Attempts validation with full address
2. If validation fails or returns zero coordinates:
   - Retries with modified address (using different address lines)
   - Attempts up to 3 variations
3. Updates record only if valid coordinates are obtained

#### Error Handling:
- Individual record failures don't halt the entire job
- Errors are logged to Rails logger
- Production errors are sent to Slack channel

## Data Flow

```
GCLAWS API
    │
    ▼
AccreditedEntitiesQueueUpdates
    │
    ├─► Fetches entity data
    ├─► Creates/updates records
    ├─► Identifies address changes
    │
    ▼
AccreditedIndividualsUpdate (batched)
    │
    ├─► Validates addresses via VAProfile
    ├─► Updates geocoding data
    └─► Final record update
```

## Database Models

### AccreditedIndividual
Stores information about accredited agents, attorneys, and representatives:
- `individual_type`: 'attorney', 'claims_agent', or 'representative'
- `ogc_id`: Unique identifier from GCLAWS
- `registration_number`: Professional registration number
- `poa_code`: Power of Attorney code
- Personal information (name, email, phone)
- Address fields (validated and geocoded)
- `raw_address`: Original address JSON from GCLAWS

### AccreditedOrganization
Stores information about Veteran Service Organizations (VSOs):
- `ogc_id`: Unique identifier from GCLAWS
- `poa_code`: Power of Attorney code
- `name`: Organization name

### Accreditation
Join table linking representatives to their VSOs:
- `accredited_individual_id`: Foreign key to AccreditedIndividual
- `accredited_organization_id`: Foreign key to AccreditedOrganization

## Monitoring

### Logs
- Rails logger for general information and errors
- Slack notifications for production errors (channel: #benefits-representation-management-notifications)

### Count Validation
The system tracks entity counts to detect potential data quality issues:
- Historical counts stored in `AccreditationApiEntityCount`
- Updates blocked if counts decrease by more than configured threshold
- Force update option available for manual intervention

## Scheduling

The `AccreditedEntitiesQueueUpdates` job is scheduled to run daily at 4:00 AM ET via the periodic jobs configuration:

```ruby
# lib/periodic_jobs.rb
mgr.register('0 4 * * *', 'RepresentationManagement::AccreditedEntitiesQueueUpdates')
```

This job will automatically queue the necessary `AccreditedIndividualsUpdate` jobs for address validation.

## Configuration Requirements

### Environment Variables/Settings:
- VAProfile API credentials for address validation
- Slack webhook URL for notifications (production)
- GCLAWS API access credentials

### Feature Flags:


## Troubleshooting

### Common Issues:

1. **Count validation failures**:
   - Check GCLAWS API for data issues
   - Use force update if decrease is expected
   - Remember: Representatives and VSOs must be processed together

2. **Address validation failures**:
   - Check VAProfile service status
   - Review address format in GCLAWS data

3. **Slow processing**:
   - Adjust SLICE_SIZE for batch processing
   - Monitor Sidekiq queue depth

4. **Missing VSO associations**:
   - Ensure VSOs are processed before representatives
   - Check that both entity types are included in the job

### Debug Commands:
```ruby
# Check current entity counts
RepresentationManagement::AccreditationApiEntityCount.new.api_counts

# Process specific failed record
record = AccreditedIndividual.find(id)
RepresentationManagement::AccreditedIndividualsUpdate.new.perform([{id: record.id, address: {...}}.to_json])

# Check representative-VSO associations
rep = AccreditedIndividual.find_by(ogc_id: 'rep_id', individual_type: 'representative')
rep.accredited_organizations

# Verify VSO exists
vso = AccreditedOrganization.find_by(ogc_id: 'vso_id')
vso.accredited_individuals
```
