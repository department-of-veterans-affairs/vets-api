# ADR-001: Submission Trigger Mechanism for GCIO Form Intake Integration

## Context

When a PDF is successfully uploaded to Lighthouse Benefits Intake, the structured form data must be immediately sent to GCIO's digitization API. The timing is critical: the structured data must be available BEFORE IBM Mail Automation processes the PDF into VBMS.

**Process Flow**:
1. PDF uploaded to Lighthouse → forwarded to Central Mail Portal
2. IBM Mail Automation fetches mail packets from Central Mail Portal
3. IBM queries GCIO for structured data (using Lighthouse UUID)
4. IBM processes PDF into VBMS using the structured data

**Requirement**: Structured data must be waiting at GCIO when IBM queries for it.

The system must:
1. Trigger GCIO submission immediately after successful Lighthouse upload
2. Not block the Lighthouse upload job
3. Handle GCIO API failures independently of Lighthouse success
4. Maintain separation of concerns between Lighthouse and GCIO integrations

## Decision

**Trigger GCIO submission immediately after successful Lighthouse PDF upload** within the `Lighthouse::SubmitBenefitsIntakeClaim` job.

### Implementation Approach

1. **Add trigger logic** in `Lighthouse::SubmitBenefitsIntakeClaim` job after successful upload
2. **Enqueue async job** (`FormIntake::SubmitFormDataJob`) immediately
3. **Non-blocking** - GCIO submission doesn't block Lighthouse job
4. **Configuration-driven** - use Flipper feature flags to control which forms trigger GCIO submissions

```ruby
# In Lighthouse::SubmitBenefitsIntakeClaim (after line 49)
response = @lighthouse_service.upload_doc(**lighthouse_service_upload_payload)
raise BenefitsIntakeClaimError, response.body unless response.success?

Rails.logger.info('Lighthouse::SubmitBenefitsIntakeClaim succeeded', generate_log_details)
StatsD.increment("#{STATSD_KEY_PREFIX}.success")

# NEW: Trigger GCIO submission immediately
trigger_gcio_submission if should_submit_to_gcio?

send_confirmation_email

# ... rest of method

private

def should_submit_to_gcio?
  return false unless @form_submission_attempt
  return false unless @claim.user_account
  
  # Use form-specific feature flag for granular control
  FormIntake.enabled_for_form?(@claim.form_id, @claim.user_account)
end

def trigger_gcio_submission
  FormIntake::SubmitFormDataJob.perform_async(
    @form_submission_attempt.form_submission_id,
    @lighthouse_service.uuid  # Pass benefits_intake_uuid for correlation
  )
  
  Rails.logger.info(
    'GCIO form intake job enqueued',
    form_submission_id: @form_submission_attempt.form_submission_id,
    benefits_intake_uuid: @lighthouse_service.uuid,
    form_id: @claim.form_id
  )
  
  StatsD.increment('gcio.trigger.enqueued', tags: ["form_id:#{@claim.form_id}"])
end
```

## Alternatives Considered

### Alternative 1: Wait for vbms Status (Original Design)

**Approach**: Trigger GCIO submission after daily polling confirms vbms status.

**Rejected because**:
- **Timing issue**: Structured data arrives days after PDF upload
- **IBM automation timing**: IBM processes PDF before structured data is available
- **Process order**: IBM automation needs data BEFORE processing to VBMS
- **Delay**: 24+ hour delay before trigger, data not ready when needed

### Alternative 2: Synchronous Call in Same Job

**Approach**: Call GCIO API synchronously within Lighthouse upload job.

```ruby
response = @lighthouse_service.upload_doc(...)
if response.success?
  FormIntake::Service.new.submit_form_data(@form_submission)  # Blocking call
end
```

**Rejected because**:
- **Blocking**: Delays Lighthouse job completion
- **Failure coupling**: GCIO failure would fail entire Lighthouse job
- **Timeout risk**: GCIO slow response impacts Lighthouse processing
- **Retry complexity**: Would need to retry both submissions together
- **Job responsibility**: Lighthouse job should only handle Lighthouse

### Alternative 3: Trigger Before Lighthouse Upload

**Approach**: Send to GCIO first, then send to Lighthouse.

**Rejected because**:
- **No UUID available**: Lighthouse UUID needed for correlation
- **Risk**: GCIO has data but Lighthouse upload could fail
- **Orphaned data**: Structured data without corresponding PDF
- **Rollback complexity**: Hard to clean up if Lighthouse fails

### Alternative 4: Separate Controller Endpoint

**Approach**: Frontend calls two separate endpoints (Lighthouse and GCIO).

**Rejected because**:
- **Frontend complexity**: Adds burden to frontend team
- **Network risk**: Double the network calls that could fail
- **Coordination**: Hard to ensure both succeed
- **Duplicate logic**: Backend should handle orchestration
- **Not backend's responsibility**: This is data pipeline, not UI concern

## Consequences

### Positive

- **Correct timing**: Structured data available when IBM automation needs it
- **Immediate trigger**: Happens within seconds of PDF upload (not days)
- **Non-blocking**: Async Sidekiq job doesn't delay Lighthouse processing
- **Independent failure**: GCIO failures don't affect Lighthouse success
- **Clear trigger point**: Single location in code to trigger from
- **Testable**: Can mock GCIO job enqueuing in Lighthouse tests
- **Configurable**: Feature flags provide fine-grained control
- **Observable**: Clear entry point for monitoring and logging
- **UUID available**: Lighthouse UUID ready for correlation

### Negative

- **Job coupling**: Adds responsibility to Lighthouse job
- **Conditional logic**: More branching in Lighthouse job
- **Testing complexity**: Must test trigger conditions in Lighthouse job
- **Failure isolation**: Must ensure GCIO errors don't propagate

### Mitigations

- **Error isolation**: Wrap trigger in begin/rescue to prevent GCIO errors affecting Lighthouse
- **Private method**: Extract to `trigger_gcio_submission` private method for clarity
- **Guard clauses**: Check feature flags and form eligibility before enqueuing
- **Testing**: Mock Sidekiq job enqueuing in Lighthouse job tests
- **Feature flags**: Can disable quickly if issues arise
- **Monitoring**: Add metrics for trigger invocation and job enqueuing
- **Documentation**: Inline comments explain timing requirement

## Implementation Notes

### Configuration

```ruby
# config/initializers/form_intake_integration.rb
module FormIntake
  # Forms eligible for GCIO integration (each requires feature flag)
  ELIGIBLE_FORMS = %w[
    21-526EZ
    21-0966
    21-4138
    20-10207
  ].freeze
  
  # Map each form to its own feature flag for independent control
  FORM_FEATURE_FLAGS = {
    '21-526EZ' => :form_intake_integration_526,
    '21-0966' => :form_intake_integration_0966,
    '21-4138' => :form_intake_integration_4138,
    '20-10207' => :form_intake_integration_10207
  }.freeze
  
  # Check if form should submit to GCIO
  def self.enabled_for_form?(form_id, user_account = nil)
    return false unless ELIGIBLE_FORMS.include?(form_id)
    
    flag = FORM_FEATURE_FLAGS[form_id]
    return false unless flag
    
    Flipper.enabled?(flag, user_account)
  end
end
```

### Feature Flags (Form-Specific)

```yaml
# config/features.yml
# Individual flags per form for granular rollout control

form_intake_integration_526:
  actor_type: user_account
  description: Enable GCIO integration for form 21-526EZ (Disability Compensation)

form_intake_integration_0966:
  actor_type: user_account
  description: Enable GCIO integration for form 21-0966 (Intent to File)

form_intake_integration_4138:
  actor_type: user_account
  description: Enable GCIO integration for form 21-4138 (Statement in Support)

form_intake_integration_10207:
  actor_type: user_account
  description: Enable GCIO integration for form 20-10207 (Priority Processing)
```

### Monitoring

```ruby
# In Lighthouse job - include benefits_intake_uuid for correlation
def trigger_gcio_submission
  FormIntake::SubmitFormDataJob.perform_async(
    @form_submission_attempt.form_submission_id,
    @lighthouse_service.uuid
  )
  
  Rails.logger.info(
    'GCIO form intake job enqueued',
    form_submission_id: @form_submission_attempt.form_submission_id,
    benefits_intake_uuid: @lighthouse_service.uuid,
    form_id: @claim.form_id
  )
  
  StatsD.increment('gcio.trigger.enqueued', tags: [
    "form_id:#{@claim.form_id}",
    "benefits_intake_uuid:#{@lighthouse_service.uuid}"
  ])
rescue => e
  # Log but don't raise - don't let GCIO trigger errors fail Lighthouse job
  Rails.logger.error(
    'Failed to enqueue GCIO job',
    error: e.message,
    form_submission_id: @form_submission_attempt.form_submission_id
  )
  StatsD.increment('gcio.trigger.enqueue_failed')
end
```

