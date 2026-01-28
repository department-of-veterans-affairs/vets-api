# ADR-003: Data Storage Approach for GCIO Form Intake Submissions

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

**Create a new `FormIntakeSubmission` model** following existing patterns from `FormSubmissionAttempt`, with a one-to-many relationship from `FormSubmission`.

### Database Schema

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_form_intake_submissions.rb
class CreateFormIntakeSubmissions < ActiveRecord::Migration[7.0]
  def change
    create_table :form_intake_submissions do |t|
      t.references :form_submission, null: false, foreign_key: true, index: true
      
      # Status tracking
      t.string :aasm_state, null: false, default: 'pending'
      t.integer :retry_count, default: 0, null: false
      
      # Correlation UUID from Lighthouse Benefits Intake submission
      t.string :benefits_intake_uuid, null: false
      
      # GCIO identifiers
      t.string :form_intake_submission_id
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
    
    add_index :form_intake_submissions, :aasm_state
    add_index :form_intake_submissions, :benefits_intake_uuid
    add_index :form_intake_submissions, :form_intake_submission_id, unique: true, where: "form_intake_submission_id IS NOT NULL"
    add_index :form_intake_submissions, :created_at
  end
end
```

### Model Implementation

```ruby
# app/models/form_intake_submission.rb
class FormIntakeSubmission < ApplicationRecord
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
      'FormIntakeSubmission state change',
      form_intake_submission_id: id,
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
    FormIntake::FailureNotificationJob.perform_async(id)
  end
end
```

### Association Updates

```ruby
# app/models/form_submission.rb
class FormSubmission < ApplicationRecord
  # ... existing code ...
  
  has_many :form_intake_submissions, dependent: :nullify
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

**Approach**: Create `form_intake_submission_attempts` separate from `form_intake_submissions`.

```
form_intake_submissions (1:N) form_intake_submission_attempts
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
- **UUID correlation**: Stores `benefits_intake_uuid` for end-to-end tracking from Lighthouse to GCIO

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
add_index :form_intake_submissions, [:form_submission_id, :aasm_state]
add_index :form_intake_submissions, [:aasm_state, :created_at]
add_index :form_intake_submissions, :last_attempted_at, where: "aasm_state = 'pending'"
```

### Data Retention

```ruby
# lib/tasks/gcio.rake
namespace :gcio do
  desc 'Archive GCIO submissions older than 7 years'
  task archive_old_submissions: :environment do
    cutoff = 7.years.ago
    FormIntakeSubmission.where('created_at < ?', cutoff).find_each do |submission|
      # Archive to S3 or data warehouse
      # Then delete from primary DB
    end
  end
end
```

### Monitoring Queries

```ruby
# Count by status
FormIntakeSubmission.group(:aasm_state).count

# Failure rate last 24h
total = FormIntakeSubmission.where('created_at > ?', 24.hours.ago).count
failed = FormIntakeSubmission.where('created_at > ?', 24.hours.ago).failed.count
failure_rate = (failed.to_f / total * 100).round(2)

# Average retry count
FormIntakeSubmission.where('created_at > ?', 24.hours.ago).average(:retry_count)
```

### Encryption Configuration

```ruby
# Follows existing pattern from FormSubmissionAttempt
class FormIntakeSubmission < ApplicationRecord
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
form_submission.form_intake_submissions

# Find failed submissions needing review
FormIntakeSubmission.failed.where('created_at > ?', 1.week.ago)

# Find pending submissions (for monitoring)
FormIntakeSubmission.pending.where('created_at < ?', 1.day.ago)

# Find by GCIO ID (for webhook callbacks)
FormIntakeSubmission.find_by(form_intake_submission_id: external_id)
```

### Performance Considerations

- Use `includes(:form_submission)` to avoid N+1
- Index on `aasm_state` for status filtering
- Index on `form_intake_submission_id` for lookups
- Partition table if volume is very high

