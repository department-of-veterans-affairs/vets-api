# ADR-002: Retry Strategy for GCIO Form Intake Submissions

## Context

GCIO API submissions may fail due to:
- Network timeouts or connectivity issues
- GCIO API temporary unavailability (503, 504 errors)
- Rate limiting (429 errors)
- Transient server errors (500, 502 errors)
- Authentication/authorization failures (401, 403 errors)

We need a retry strategy that:
1. Handles transient failures gracefully
2. Doesn't overwhelm the GCIO API with rapid retries
3. Provides sufficient time for recovery
4. Fails permanently for unrecoverable errors
5. Maintains audit trail of all attempts
6. Follows existing vets-api patterns

## Decision

**Use Sidekiq's built-in retry mechanism with exponential backoff** configured for 16 retries over ~2 days, consistent with existing vets-api jobs.

### Configuration

```ruby
class FormIntake::SubmitFormDataJob
  include Sidekiq::Job
  
  # Retry for 2d 1h 47m 12s (same as Lighthouse jobs)
  sidekiq_options retry: 16, queue: 'low'
  
  # Handle retry exhaustion
  sidekiq_retries_exhausted do |msg, _ex|
    form_submission_id = msg['args'].first
    form_intake_submission = FormIntakeSubmission.find_by(form_submission_id: form_submission_id)
    
    form_intake_submission&.fail!
    
    Rails.logger.error(
      'FormIntake::SubmitFormDataJob retries exhausted',
      form_submission_id: form_submission_id,
      form_intake_submission_id: form_intake_submission&.id,
      error: msg['error_message']
    )
    
    StatsD.increment('gcio.submit_form_data_job.exhausted')
    
    # Send failure notification if configured
    FormIntake::FailureNotificationJob.perform_async(form_submission_id) if Flipper.enabled?(:form_intake_failure_notifications)
  end
end
```

### Retry Schedule (Sidekiq Default)

| Attempt | Delay | Cumulative Time |
|---------|-------|-----------------|
| 1       | ~25s  | 25s             |
| 2       | ~55s  | 1m 20s          |
| 3       | ~2m   | 3m 20s          |
| 4       | ~5m   | 8m 20s          |
| 5       | ~10m  | 18m 20s         |
| 6       | ~21m  | 39m 20s         |
| 7       | ~42m  | 1h 21m          |
| 8       | ~1h   | 2h 21m          |
| 9       | ~2h   | 4h 21m          |
| 10      | ~4h   | 8h 21m          |
| 11      | ~8h   | 16h 21m         |
| 12      | ~11h  | 1d 3h 21m       |
| 13      | ~11h  | 1d 14h 21m      |
| 14      | ~11h  | 2d 1h 21m       |
| 15      | ~11h  | 2d 12h 21m      |
| 16      | ~11h  | 2d 23h 21m      |

### Error Classification

```ruby
module FormIntake
  class SubmitFormDataJob
    # Errors that should NOT retry
    NON_RETRYABLE_ERRORS = [
      400, # Bad Request - data issue
      401, # Unauthorized - auth config issue
      403, # Forbidden - permission issue
      404, # Not Found - wrong endpoint
      422  # Unprocessable Entity - validation failure
    ].freeze
    
    def perform(form_submission_id)
      # ... job logic ...
    rescue FormIntake::ServiceError => e
      if NON_RETRYABLE_ERRORS.include?(e.status_code)
        # Mark as failed immediately, don't retry
        form_intake_submission.fail!
        Rails.logger.error('Non-retryable GCIO error', error: e, status: e.status_code)
        StatsD.increment('gcio.non_retryable_error', tags: ["status:#{e.status_code}"])
        return # Don't re-raise, prevents retry
      end
      
      # For retryable errors, update attempt count and re-raise
      form_intake_submission.increment_retry_count!
      raise # Let Sidekiq handle retry
    end
  end
end
```

## Alternatives Considered

### Alternative 1: Custom Retry Logic with Active Job

**Approach**: Use Rails Active Job with custom retry logic.

**Rejected because**:
- Sidekiq is already the standard in vets-api
- Would duplicate Sidekiq's battle-tested retry mechanism
- Active Job adds abstraction layer without benefit
- All existing jobs use Sidekiq directly
- Sidekiq UI provides retry management

### Alternative 2: Aggressive Retry (25 retries)

**Approach**: Increase retry count to 25 attempts over 1 week.

**Rejected because**:
- Extended retry periods delay failure detection
- Ties up resources for likely-permanent failures
- 2 days is sufficient based on existing patterns
- Can manually retry if GCIO has extended outage
- Inconsistent with existing Lighthouse job patterns (16 retries)

### Alternative 3: Immediate Retry with Circuit Breaker

**Approach**: Retry immediately but use circuit breaker to stop after N consecutive failures.

**Rejected because**:
- Exponential backoff is more respectful to failing service
- Circuit breaker adds complexity
- Sidekiq's delay prevents thundering herd
- Existing vets-api pattern uses exponential backoff
- Can still add circuit breaker at HTTP client level if needed

### Alternative 4: No Retries, Manual Remediation Only

**Approach**: Don't retry automatically, require manual intervention.

**Rejected because**:
- Poor user experience for transient failures
- Increases operational burden
- Existing patterns use automatic retries
- Most API failures are transient

## Consequences

### Positive

- **Proven pattern**: Matches existing Lighthouse integration jobs
- **Handles transient failures**: Exponential backoff allows time for recovery
- **Non-invasive**: Doesn't overwhelm failing service
- **Observable**: Sidekiq UI shows retry queue and attempts
- **Configurable**: Can adjust retry count via sidekiq_options
- **Audit trail**: Each attempt logged and recorded in database
- **Failure handling**: Retry exhaustion callback for permanent failures

### Negative

- **Delayed feedback**: Final failure known only after ~2 days
- **Resource usage**: Failed jobs occupy queue space
- **Limited customization**: Sidekiq retry schedule is global

### Mitigations

- **Monitoring**: Alert on high retry rates
- **Manual override**: Can manually fail jobs in Sidekiq UI
- **Error classification**: Non-retryable errors fail immediately
- **Feature flags**: Can disable integration quickly
- **Notifications**: Alert on retry exhaustion

## Implementation Notes

### Monitoring Metrics

```ruby
# Track each attempt - include benefits_intake_uuid for correlation with Lighthouse submission
StatsD.increment('gcio.submit_form_data_job.attempt', tags: [
  "form_type:#{form_type}",
  "attempt:#{retry_count}",
  "benefits_intake_uuid:#{benefits_intake_uuid}"
])

# Track by error type
StatsD.increment('gcio.submit_form_data_job.error', tags: [
  "status:#{status_code}",
  "retryable:#{retryable}",
  "benefits_intake_uuid:#{benefits_intake_uuid}"
])

# Track exhaustion
StatsD.increment('gcio.submit_form_data_job.exhausted', tags: [
  "form_type:#{form_type}",
  "benefits_intake_uuid:#{benefits_intake_uuid}"
])
```

### DataDog APM Integration

```ruby
def perform(form_submission_id)
  Datadog::Tracing.trace('gcio.submit_form_data_job') do |span|
    span.set_tag('form_submission_id', form_submission_id)
    span.set_tag('retry_count', retry_count)
    
    # Include benefits_intake_uuid for correlation with Lighthouse submission
    span.set_tag('benefits_intake_uuid', benefits_intake_uuid)
    span.set_tag('form_type', form_type)
    
    # ... job logic ...
  end
end
```

### Database Tracking

Each retry updates the `FormIntakeSubmission` record:

```ruby
def increment_retry_count!
  increment!(:retry_count)
  update!(
    last_error_message: error_message,
    last_attempted_at: Time.current
  )
end
```

### Benefits Intake UUID Correlation

Store and use the `benefits_intake_uuid` from the Lighthouse submission for tracking:

```ruby
# In FormIntakeSubmission model
class FormIntakeSubmission < ApplicationRecord
  belongs_to :form_submission
  
  # Delegate to get the benefits_intake_uuid
  def benefits_intake_uuid
    form_submission.form_submission_attempts
                   .order(created_at: :desc)
                   .first&.benefits_intake_uuid
  end
end

# In FormIntake::SubmitFormDataJob
def perform(form_submission_id)
  @form_submission = FormSubmission.find(form_submission_id)
  @benefits_intake_uuid = latest_benefits_intake_uuid
  
  # Include in all logging and metrics
  Rails.logger.info(
    'FormIntake job started',
    form_submission_id: form_submission_id,
    benefits_intake_uuid: @benefits_intake_uuid
  )
  
  StatsD.increment('gcio.submit_form_data_job.attempt', tags: [
    "form_type:#{@form_submission.form_type}",
    "benefits_intake_uuid:#{@benefits_intake_uuid}"
  ])
end

def latest_benefits_intake_uuid
  @form_submission.form_submission_attempts
                  .where(aasm_state: 'vbms')
                  .order(created_at: :desc)
                  .first&.benefits_intake_uuid
end
```

### Alerting

```ruby
# Alert if retry rate is high
if retry_count > 5
  Rails.logger.warn(
    'GCIO submission high retry count',
    form_submission_id: form_submission_id,
    retry_count: retry_count
  )
end
```

## Error Scenarios and Responses

| Error Code | Retry? | Rationale |
|------------|--------|-----------|
| 400 | No | Bad request, data issue needs fixing |
| 401 | No | Auth failure, config issue |
| 403 | No | Permission denied, access issue |
| 404 | No | Endpoint not found, config issue |
| 408 | Yes | Timeout, transient |
| 422 | No | Validation error, data issue |
| 429 | Yes | Rate limit, will recover |
| 500 | Yes | Server error, likely transient |
| 502 | Yes | Bad gateway, likely transient |
| 503 | Yes | Service unavailable, transient |
| 504 | Yes | Gateway timeout, transient |
| Network | Yes | Connection issues, transient |

