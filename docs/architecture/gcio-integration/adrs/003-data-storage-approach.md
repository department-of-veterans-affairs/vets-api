# ADR-003: Data Storage Approach for GCIO Submissions

## Status
Accepted

## Context

We need to track GCIO API submission attempts and outcomes for:
1. **Audit purposes** - Who submitted what, when, and what happened
2. **Debugging** - Troubleshooting failed submissions
3. **Monitoring** - Understanding success/failure rates
4. **Retry coordination** - Preventing duplicate submissions
5. **Compliance** - Maintaining records of data sent to external systems
6. **Reporting** - Providing status to stakeholders

### Data Requirements

**Essential Data**:
- Link to original `FormSubmission`
- Submission status (pending, success, failed)
- Request payload sent to GCIO
- Response from GCIO API
- Retry attempt count
- Error messages
- Timestamps (created, updated, submitted)
- GCIO submission ID (if provided)

**Sensitive Data Considerations**:
- Form data contains PII
- Must encrypt sensitive fields
- Must follow existing vets-api encryption patterns
- Must comply with VA privacy requirements

### Existing Patterns

vets-api already has established patterns:
- `FormSubmission` - stores original form data (encrypted)
- `FormSubmissionAttempt` - tracks Lighthouse submission attempts
- Uses Lockbox with KMS for encryption
- AASM for state machine management

## Decision

**Create a new `GcioSubmission` model** following existing patterns from `FormSubmissionAttempt`, with a one-to-many relationship from `FormSubmission`.

### Database Schema

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_gcio_submissions.rb
class CreateGcioSubmissions < ActiveRecord::Migration[7.0]
  def change
    create_table :gcio_submissions do |t|
      t.references :form_submission, null: false, foreign_key: true, index: true
      
      # Status tracking
      t.string :aasm_state, null: false, default: 'pending'
      t.integer :retry_count, default: 0, null: false
      
      # GCIO identifiers
      t.string :gcio_submission_id
      t.string :gcio_tracking_number
      
      # Encrypted fields (using Lockbox)
      t.text :request_payload_ciphertext
      t.text :response_ciphertext
      t.text :error_message_ciphertext
      
      # Timestamps
      t.datetime :submitted_at
      t.datetime :completed_at
      t.datetime :last_attempted_at
      
      t.timestamps
    end
    
    add_index :gcio_submissions, :aasm_state
    add_index :gcio_submissions, :gcio_submission_id, unique: true, where: "gcio_submission_id IS NOT NULL"
    add_index :gcio_submissions, :created_at
  end
end
```

### Model Implementation

```ruby
# app/models/gcio_submission.rb
class GcioSubmission < ApplicationRecord
  include AASM
  
  belongs_to :form_submission
  has_one :saved_claim, through: :form_submission
  has_one :user_account, through: :form_submission
  
  # Lockbox encryption (same pattern as FormSubmissionAttempt)
  has_kms_key
  has_encrypted :request_payload, :response, :error_message, 
                key: :kms_key, **lockbox_options
  
  validates :form_submission, presence: true
  validates :retry_count, numericality: { greater_than_or_equal_to: 0 }
  
  aasm do
    after_all_transitions :log_status_change
    
    state :pending, initial: true
    state :submitted # Successfully sent to GCIO
    state :success   # GCIO confirmed receipt
    state :failed    # Permanent failure
    
    event :submit do
      transitions from: :pending, to: :submitted
    end
    
    event :succeed do
      after do
        update!(completed_at: Time.current)
      end
      transitions from: [:pending, :submitted], to: :success
    end
    
    event :fail do
      after do
        update!(completed_at: Time.current)
        notify_on_failure if should_notify?
      end
      transitions from: [:pending, :submitted], to: :failed
    end
  end
  
  def log_status_change
    Rails.logger.info(
      'GcioSubmission state change',
      gcio_submission_id: id,
      form_submission_id: form_submission_id,
      form_type: form_submission.form_type,
      from_state: aasm.from_state,
      to_state: aasm.to_state
    )
  end
  
  def increment_retry_count!
    increment!(:retry_count)
    update!(last_attempted_at: Time.current)
  end
  
  private
  
  def should_notify?
    Flipper.enabled?(:gcio_failure_notifications, user_account)
  end
  
  def notify_on_failure
    Gcio::FailureNotificationJob.perform_async(id)
  end
end
```

### Association Updates

```ruby
# app/models/form_submission.rb
class FormSubmission < ApplicationRecord
  # ... existing code ...
  
  has_many :gcio_submissions, dependent: :nullify
end
```

## Alternatives Considered

### Alternative 1: Reuse FormSubmissionAttempt Table

**Approach**: Add GCIO-specific columns to the existing `form_submission_attempts` table.

**Rejected because**:
- Conflates Lighthouse and GCIO concerns
- `FormSubmissionAttempt` is 1:1 with Lighthouse submission
- GCIO may have multiple attempts per Lighthouse submission
- Different failure modes and retry logic
- Harder to query and report on separately
- Schema pollution with conditional columns

### Alternative 2: Store in Redis/Cache Only

**Approach**: Use Redis for temporary tracking, no permanent storage.

**Rejected because**:
- Audit requirements mandate persistent storage
- No historical data for analysis
- Redis eviction policies could lose data
- Harder to debug issues after the fact
- No mechanism for manual remediation
- Violates compliance requirements

### Alternative 3: Separate Status Tracking Table

**Approach**: Create `gcio_submission_attempts` separate from `gcio_submissions`.

```
gcio_submissions (1:N) gcio_submission_attempts
```

**Rejected because**:
- Over-engineered for current needs
- `retry_count` is sufficient for tracking attempts
- Can add if detailed attempt tracking needed later
- Increases query complexity
- More tables to maintain

### Alternative 4: Event Sourcing

**Approach**: Store all state changes as immutable events.

**Rejected because**:
- No existing event sourcing infrastructure
- Overkill for current requirements
- Increased storage and query complexity
- Not consistent with vets-api patterns
- Can reconstruct history from logs if needed

### Alternative 5: External Audit Database

**Approach**: Send audit data to separate audit database or data warehouse.

**Rejected because**:
- Adds infrastructure complexity
- Not needed for operational queries
- Can export to warehouse later if needed
- Need real-time access for retry logic
- All form data already in primary DB

## Consequences

### Positive

- **Follows existing patterns**: Mirrors `FormSubmissionAttempt` structure
- **Full audit trail**: All submissions tracked with timestamps
- **Encrypted PII**: Sensitive data protected via Lockbox
- **Query flexibility**: Can easily report on GCIO submission status
- **State machine**: AASM provides reliable state transitions
- **Relationship integrity**: Foreign keys prevent orphaned records
- **Index optimization**: Indexes support common query patterns
- **Manual remediation**: Can identify and resubmit failed records

### Negative

- **Storage growth**: New table adds to database size
- **Schema maintenance**: Additional migration to manage
- **Query joins**: Need joins to get full context
- **Encryption overhead**: Slight performance cost for encryption

### Mitigations

- **Data retention policy**: Archive/delete old records after N years
- **Pagination**: Use pagination for large result sets
- **Eager loading**: Use `includes` to optimize joins
- **Background encryption**: Encrypt in job, not inline

## Implementation Notes

### Indexes

```ruby
# For common queries
add_index :gcio_submissions, [:form_submission_id, :aasm_state]
add_index :gcio_submissions, [:aasm_state, :created_at]
add_index :gcio_submissions, :last_attempted_at, where: "aasm_state = 'pending'"
```

### Data Retention

```ruby
# lib/tasks/gcio.rake
namespace :gcio do
  desc 'Archive GCIO submissions older than 7 years'
  task archive_old_submissions: :environment do
    cutoff = 7.years.ago
    GcioSubmission.where('created_at < ?', cutoff).find_each do |submission|
      # Archive to S3 or data warehouse
      # Then delete from primary DB
    end
  end
end
```

### Monitoring Queries

```ruby
# Count by status
GcioSubmission.group(:aasm_state).count

# Failure rate last 24h
total = GcioSubmission.where('created_at > ?', 24.hours.ago).count
failed = GcioSubmission.where('created_at > ?', 24.hours.ago).failed.count
failure_rate = (failed.to_f / total * 100).round(2)

# Average retry count
GcioSubmission.where('created_at > ?', 24.hours.ago).average(:retry_count)
```

### Encryption Configuration

```ruby
# Follows existing pattern from FormSubmissionAttempt
class GcioSubmission < ApplicationRecord
  has_kms_key
  has_encrypted :request_payload, :response, :error_message,
                key: :kms_key, **lockbox_options
                
  # Ignored columns for old unencrypted fields (if migrating)
  self.ignored_columns += %w[request_payload response error_message]
end
```

## Schema Evolution Considerations

### Future Enhancements

If we need more detailed tracking later:

```ruby
# Could add
t.jsonb :metadata  # For flexible additional data
t.integer :http_status_code
t.string :endpoint_url
t.text :request_headers_ciphertext
```

### Backwards Compatibility

- Model uses sensible defaults
- Can add columns without breaking existing code
- State machine allows adding new states

## Data Access Patterns

### Common Queries

```ruby
# Find all GCIO submissions for a form
form_submission.gcio_submissions

# Find failed submissions needing review
GcioSubmission.failed.where('created_at > ?', 1.week.ago)

# Find pending submissions (for monitoring)
GcioSubmission.pending.where('created_at < ?', 1.day.ago)

# Find by GCIO ID (for webhook callbacks)
GcioSubmission.find_by(gcio_submission_id: external_id)
```

### Performance Considerations

- Use `includes(:form_submission)` to avoid N+1
- Index on `aasm_state` for status filtering
- Index on `gcio_submission_id` for lookups
- Partition table if volume is very high

## References

- [FormSubmissionAttempt Model](../../../../app/models/form_submission_attempt.rb)
- [FormSubmission Model](../../../../app/models/form_submission.rb)
- [Lockbox Encryption](https://github.com/ankane/lockbox)
- [AASM State Machine](https://github.com/aasm/aasm)

## Review

- **Author**: Architecture Team
- **Date**: 2026-01-09
- **Reviewers**: Platform Team, Backend Team, Security Team
- **Next Review**: 2026-04-09 (90 days)

