# ADR-003: Store GCIO Submission State in Dedicated Table

## Context

GCIO submissions need tracking for:
- Audit trail (what was sent, when, status)
- Retry management (track attempts, errors)
- Debugging (correlate with Lighthouse UUID)
- Metrics (success/failure rates)

We need to decide where to store this state and what data to track.

## Decision

**Create dedicated `form_intake_submissions` table** with AASM state machine and encrypted PII fields.

```ruby
create_table :form_intake_submissions do |t|
  t.references :form_submission, foreign_key: true
  t.string :benefits_intake_uuid, null: false  # Lighthouse UUID
  t.string :aasm_state, default: 'pending'
  t.text :encrypted_payload  # Lockbox encrypted
  t.text :encrypted_response
  t.integer :retry_count, default: 0
  t.datetime :submitted_at
  t.timestamps
end
```

**State flow**: `pending` → `submitted` → `success` or `failed`

## Alternatives Considered

**Add columns to form_submissions**: Rejected - Couples concerns, clutters existing table  
**Store in Redis**: Rejected - Need persistent audit trail  
**No storage (fire and forget)**: Rejected - No visibility or debugging capability  

## Consequences

**Positive**:
- Complete audit trail
- Supports retry logic
- Encrypted PII (Lockbox + KMS)
- Can query submission history
- Doesn't modify existing tables

**Negative**:
- Additional table to maintain
- Storage costs for encrypted payloads

**Mitigation**: Retention policy (archive after 90 days), indexes for performance
