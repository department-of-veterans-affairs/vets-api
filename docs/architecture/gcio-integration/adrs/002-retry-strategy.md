# ADR-002: Use Sidekiq's 16-Retry Pattern for GCIO Submissions

## Context

GCIO API submissions may fail due to network issues, API unavailability, rate limiting, or server errors. We need a retry strategy that:
- Handles transient failures gracefully
- Doesn't overwhelm the API with rapid retries
- Provides sufficient time for recovery
- Fails permanently for unrecoverable errors

## Decision

**Use Sidekiq's built-in retry mechanism with 16 retries over ~2 days** (matches existing Lighthouse job patterns).

```ruby
class FormIntake::SubmitFormDataJob
  sidekiq_options retry: 16, queue: 'low'
  
  # Non-retryable errors (fail immediately)
  NON_RETRYABLE = [400, 401, 403, 404, 422]
  
  def perform(form_submission_id, benefits_intake_uuid)
    # ... submission logic ...
  rescue FormIntake::ServiceError => e
    return if NON_RETRYABLE.include?(e.status_code)  # Don't retry
    raise  # Retry for other errors
  end
end
```

**Retry schedule**: Exponential backoff from 25s to 11h between attempts.

## Alternatives Considered

**Custom retry logic**: Rejected - Sidekiq's is battle-tested  
**Aggressive retries (25x)**: Rejected - 2 days is sufficient, matches patterns  
**No retries**: Rejected - Most failures are transient  

## Consequences

**Positive**:
- Proven pattern (matches Lighthouse jobs)
- Handles transient failures
- Exponential backoff prevents overwhelming API
- Sidekiq UI for monitoring

**Negative**:
- Final failure known only after ~2 days
- Failed jobs occupy queue space

**Mitigation**: Error classification (non-retryable fail immediately), monitoring alerts
