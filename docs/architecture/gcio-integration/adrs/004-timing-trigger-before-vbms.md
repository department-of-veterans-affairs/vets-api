# ADR-004: Trigger GCIO Submission Before VBMS Processing

## Context

The GCIO digitization API receives structured JSON form data that IBM Mail Automation uses when processing PDFs into VBMS. The timing of when this structured data is sent is critical to the entire workflow.

### The Process Chain

```
VA.gov → Lighthouse → Central Mail Portal → IBM Automation → VBMS
              ↓                                     ↓
         (PDF Upload)                     (Needs structured data)
```

**IBM Mail Automation Process**:
1. IBM polls Central Mail Portal for new mail packets
2. IBM queries GCIO API for structured data (using Lighthouse UUID as key)
3. IBM uses structured data to determine correct VBMS processing actions
4. IBM processes PDF into VBMS with correct metadata/routing

**Critical Requirement**: The structured data must be available at GCIO API BEFORE IBM queries for it.

### Timing Options

1. **Before Lighthouse upload**: Data ready, but no UUID for correlation yet
2. **After Lighthouse upload**: ✅ UUID available, data can be sent immediately
3. **After polling detects success**: ❌ Days too late, IBM already processed PDF
4. **After vbms status**: ❌ Weeks too late, PDF already in VBMS

## Decision

**Trigger GCIO submission immediately after successful Lighthouse PDF upload** (Option 2).

The trigger point is in `Lighthouse::SubmitBenefitsIntakeClaim` job, right after the upload succeeds and the UUID is available:

```ruby
# Line 45-46: Upload to Lighthouse
response = @lighthouse_service.upload_doc(**lighthouse_service_upload_payload)
raise BenefitsIntakeClaimError, response.body unless response.success?

# Line 48-49: Upload succeeded, UUID available
Rails.logger.info('Lighthouse::SubmitBenefitsIntakeClaim succeeded', ...)
StatsD.increment("#{STATSD_KEY_PREFIX}.success")

# NEW: Immediately enqueue GCIO submission (async, non-blocking)
trigger_gcio_submission if should_submit_to_gcio?

# Continue with confirmation email
send_confirmation_email
```

### Why This Works

1. **UUID available**: Lighthouse returns UUID immediately after upload
2. **Non-blocking**: Async job enqueuing takes milliseconds
3. **Fast delivery**: GCIO receives data within seconds/minutes
4. **IBM ready**: Data waiting when IBM automation queries for it
5. **Failure independence**: GCIO errors don't affect Lighthouse success

## Timing Analysis

### Current System (After vbms Status)
```
T+0s:      PDF uploaded to Lighthouse
T+24h:     Polling job runs, checks status (still "pending")
T+48h:     Polling job runs, status might be "success"
T+72h+:    Polling job runs, status changes to "vbms"
           ↓ Trigger GCIO submission
T+72h+30s: GCIO receives structured data
```
**Problem**: IBM processed the PDF days ago without structured data

### New System (After Lighthouse Upload)
```
T+0s:      PDF uploaded to Lighthouse
T+1s:      Trigger GCIO submission (async)
T+2-10s:   GCIO receives structured data
T+minutes: IBM queries GCIO, finds data
T+minutes: IBM processes PDF with structured data
```
**Solution**: Structured data ready within seconds

## Alternatives Considered

### Webhook from Lighthouse

**Approach**: Lighthouse sends webhook when upload succeeds, webhook triggers GCIO.

**Rejected because**:
- No webhook mechanism exists in Lighthouse API
- Would require Lighthouse team to implement
- Adds external dependency
- We already have the success signal in our job

### Separate Orchestration Service

**Approach**: Create dedicated service to coordinate Lighthouse + GCIO submissions.

**Rejected because**:
- Over-engineered for the requirement
- Adds unnecessary abstraction layer
- Simple addition to existing job is sufficient
- More code to maintain

### Queue-Based Coordination

**Approach**: Lighthouse job publishes to queue, separate consumer sends to GCIO.

**Rejected because**:
- No message queue infrastructure in vets-api
- Sidekiq job enqueuing provides same benefit
- Would need to add Kafka/SNS
- Adds operational complexity

## Consequences

### Positive

- **Correct timing**: Data ready when IBM needs it (seconds, not days)
- **Simple implementation**: Add ~10 lines to existing job
- **Leverages Sidekiq**: Uses existing async infrastructure
- **UUID correlation**: Lighthouse UUID available for tracking
- **Fast feedback**: GCIO errors detected within minutes (not days)
- **Testable**: Can verify trigger logic in existing job tests

### Negative

- **Job responsibility growth**: Lighthouse job now knows about GCIO
- **More failure modes**: GCIO enqueuing could theoretically fail
- **Testing surface**: Must test trigger conditions in Lighthouse job

### Mitigations

- **Error handling**: Wrap in rescue block, don't let GCIO errors fail Lighthouse
- **Feature flags**: Can disable without code changes
- **Monitoring**: Track enqueue success/failure separately
- **Testing**: Mock Sidekiq job enqueuing, verify conditions
- **Documentation**: Inline comments explain timing requirement

## Implementation Pattern

```ruby
def perform(saved_claim_id)
  # ... existing Lighthouse logic ...
  
  response = @lighthouse_service.upload_doc(...)
  raise BenefitsIntakeClaimError, response.body unless response.success?
  
  # Success! Now trigger GCIO
  begin
    trigger_gcio_submission if should_submit_to_gcio?
  rescue => e
    # Log but don't fail - GCIO is supplementary
    Rails.logger.error('GCIO trigger failed', error: e.message)
    StatsD.increment('gcio.trigger.error')
  end
  
  # Continue normal flow
  send_confirmation_email
  @lighthouse_service.uuid
end
```

## Success Criteria

✅ Structured data arrives at GCIO within 30 seconds of Lighthouse upload  
✅ IBM automation finds data when querying GCIO  
✅ Lighthouse job completes successfully regardless of GCIO status  
✅ GCIO failures retry independently (16 attempts)  
✅ All submissions correlated via benefits_intake_uuid  

## Timeline Impact

| Metric | Old Design | New Design | Improvement |
|--------|------------|------------|-------------|
| Data available at GCIO | 24-72+ hours | 2-30 seconds | **99.9% faster** |
| IBM can use data | Never (too late) | Always (ready) | **100% availability** |
| Debug correlation | Hard (days apart) | Easy (same UUID) | **Immediate** |

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| GCIO job enqueue fails | Low | Medium | Try/catch block; monitoring |
| GCIO API slow/down | Medium | Low | Async + retries; doesn't block Lighthouse |
| Wrong form types triggered | Low | Low | Feature flags per form type |
| Lighthouse job instability | Low | Medium | Comprehensive testing before deploy |

## Validation Plan

### Development Testing
1. Upload PDF to Lighthouse (use test form)
2. Verify GCIO job enqueued within 1 second
3. Verify Lighthouse job completes successfully
4. Check logs for benefits_intake_uuid correlation

### Staging Testing
1. Submit real form through UI
2. Monitor DataDog for job enqueuing metric
3. Verify timing: GCIO submission within 30 seconds
4. Confirm IBM can query structured data

### Production Rollout
1. Enable for 1% of users via feature flag
2. Monitor for 48 hours
3. Check success rates and timing
4. Gradually increase percentage

## Related Decisions

- [ADR-001: Submission Trigger Mechanism](./001-submission-trigger-mechanism.md) - Implementation details
- [ADR-002: Retry Strategy](./002-retry-strategy.md) - How failures are handled
- See also: [TIMING-ARCHITECTURE-UPDATE.md](../TIMING-ARCHITECTURE-UPDATE.md) - Full timing analysis

