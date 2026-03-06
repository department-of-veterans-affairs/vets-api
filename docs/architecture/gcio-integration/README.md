# GCIO Form Intake Integration

## Overview

Automatically sends structured JSON form data to GCIO's digitization API immediately after successful Lighthouse PDF uploads. This enables IBM Mail Automation to process forms with enhanced accuracy.

**Status**: Phase 1 Complete (Database foundation) | Phase 2 In Progress (Integration layer)

---

## Quick Links

- **[Integration Comparison](./INTEGRATION-COMPARISON.md)** - 🎯 **START HERE** - Which guide should I use?
- **[Simple Forms Integration Guide](./SIMPLE-FORMS-INTEGRATION.md)** - How to add a simple form
- **[Non-Simple Forms Integration Guide](./NON-SIMPLE-FORMS-INTEGRATION.md)** - How to integrate any non-simple form
- **[C4 Diagrams](./c4-diagrams.md)** - Architecture visualizations
- **[ADRs](./adrs/)** - Key architectural decisions
- **[Rollout Strategy](./ROLLOUT-STRATEGY.md)** - Deployment plan
- **[Stories](./stories/)** - Implementation tasks

---

## Why This Integration?

**Problem**: IBM Mail Automation processes PDFs from Central Mail Portal into VBMS. Without structured data, IBM relies on OCR (error-prone).

**Solution**: Send structured JSON to GCIO immediately after PDF upload. IBM queries GCIO for this data when processing.

**Result**: Faster, more accurate form processing into VBMS.

---

## How It Works

```
1. Veteran submits form → vets-api
2. vets-api uploads PDF → Lighthouse (existing)
3. vets-api sends JSON → GCIO (new, immediate)
4. IBM fetches PDF from Central Mail Portal
5. IBM queries GCIO for JSON (using Lighthouse UUID)
6. IBM processes into VBMS with structured data
```

**Critical timing**: JSON must be at GCIO before IBM processes PDF (seconds, not days).

---

## Architecture Highlights

### Components

| Component | Purpose | Technology |
|-----------|---------|------------|
| `FormIntake::Service` | GCIO API client | Faraday, fwdproxy |
| `FormIntake::SubmitFormDataJob` | Async submission | Sidekiq (16 retries) |
| `FormIntake::Mappers` | Data transformation | Ruby classes |
| `FormIntakeSubmission` | State tracking | ActiveRecord + AASM |

### Trigger Points

**Simple Forms** (e.g., 21P-601, 21-0966): `FormSubmissionAttempt.after_commit` callback → [Simple Forms Integration Guide](./SIMPLE-FORMS-INTEGRATION.md)  
**Non-Simple Forms** (e.g., 21-526EZ, 21P-527EZ, custom forms): Your Lighthouse upload flow → [Non-Simple Forms Integration Guide](./NON-SIMPLE-FORMS-INTEGRATION.md)

Both enqueue `FormIntake::SubmitFormDataJob` (async, non-blocking).

---

## Which Integration Guide Do I Use?

| Your Form Uses... | Guide to Follow |
|-------------------|-----------------|
| `SimpleFormsApi::V1::UploadsController` | **[Simple Forms Guide](./SIMPLE-FORMS-INTEGRATION.md)** |
| Automatic `FormSubmissionAttempt.after_commit` trigger | **[Simple Forms Guide](./SIMPLE-FORMS-INTEGRATION.md)** |
| `SavedClaim` model | **[Non-Simple Forms Guide](./NON-SIMPLE-FORMS-INTEGRATION.md)** |
| Custom form implementation | **[Non-Simple Forms Guide](./NON-SIMPLE-FORMS-INTEGRATION.md)** |
| Module-specific controllers (e.g., `Pensions::`, `Burials::`) | **[Non-Simple Forms Guide](./NON-SIMPLE-FORMS-INTEGRATION.md)** |
| Custom Lighthouse job | **[Non-Simple Forms Guide](./NON-SIMPLE-FORMS-INTEGRATION.md)** |
| Any form NOT using Simple Forms API | **[Non-Simple Forms Guide](./NON-SIMPLE-FORMS-INTEGRATION.md)** |

**Still not sure?** 
- Uses Simple Forms API endpoint (`/simple_forms_api/v1/uploads`) → Simple Forms Guide
- Everything else → Non-Simple Forms Guide

### Data Flow

```
FormSubmission (original data)
  ↓
FormSubmissionAttempt (Lighthouse tracking)
  ↓ after_commit callback
FormIntake::SubmitFormDataJob (enqueued)
  ↓
FormIntake::Mappers (transform to GCIO format)
  ↓
FormIntake::Service (HTTP client)
  ↓ via fwdproxy (mTLS)
GCIO Digitization API
  ↓
FormIntakeSubmission (state: success/failed)
```

---

## Key Decisions (ADRs)

| ADR | Decision | Rationale |
|-----|----------|-----------|
| [001](./adrs/001-submission-trigger-mechanism.md) | Trigger immediately after Lighthouse | Data ready when IBM needs it |
| [002](./adrs/002-retry-strategy.md) | 16 retries over 2 days | Matches Lighthouse patterns |
| [003](./adrs/003-data-storage-approach.md) | Dedicated table with encryption | Audit trail + security |
| [004](./adrs/004-timing-trigger-before-vbms.md) | Send before IBM processes | Can't send after (too late) |
| [005](./adrs/005-form-specific-feature-flags.md) | Per-form feature flags | Granular rollout control |

---

## Adding a New Form

See **[SIMPLE-FORMS-INTEGRATION.md](./SIMPLE-FORMS-INTEGRATION.md)** for detailed guide.

**Quick steps**:
1. Create mapper class (inherit from `BaseMapper`)
2. Register in `FormMapperRegistry`
3. Add feature flag to `config/features.yml`
4. Add to `ELIGIBLE_FORMS` list
5. Write tests

**Time estimate**: 2-4 hours per form

---

## Feature Flags

Forms are controlled independently via Flipper:

```yaml
form_intake_integration_526:   # 21-526EZ
  actor_type: user
  
form_intake_integration_0966:  # 21-0966
  actor_type: user
  
form_intake_integration_601:   # 21P-601
  actor_type: user
```

**Rollout**: Enable per user → percentage → 100%

---

## Monitoring

### Metrics (StatsD/DataDog)

```
gcio.trigger.enqueued              # Job enqueued
gcio.submission.success            # API success
gcio.submission.failed             # API failure
gcio.submission.retry              # Retry attempt
```

### Logs

```ruby
# Success
"GCIO form intake job enqueued" (form_submission_id, benefits_intake_uuid)
"GCIO submission successful" (tracking_id, response_time)

# Failure
"GCIO submission failed" (error, status_code, retry_count)
```

### Dashboards

- **Success rate**: `gcio.submission.success / (success + failed)`
- **Retry rate**: `gcio.submission.retry / total`
- **Latency**: `gcio.submission.duration` (p50, p95, p99)

---

## Security

- **Encryption**: All PII encrypted with Lockbox + KMS
- **Authentication**: mTLS via fwdproxy
- **Certificates**: Stored in AWS SSM Parameter Store
- **Network**: Outbound only through fwdproxy

---

## Error Handling

### Non-Retryable Errors (Fail Immediately)
- 400 Bad Request (invalid payload)
- 401 Unauthorized (auth issue)
- 403 Forbidden (permission issue)
- 404 Not Found (endpoint issue)
- 422 Unprocessable Entity (validation error)

### Retryable Errors (16 Attempts)
- 500 Internal Server Error
- 502 Bad Gateway
- 503 Service Unavailable
- 504 Gateway Timeout
- Network errors (timeouts, connection refused)

**Retry schedule**: 25s, 2m, 5m, 15m, 30m, 1h, 2h, 4h, 8h, 11h (total ~2 days)

---

## Testing

### Unit Tests
```bash
bundle exec rspec spec/models/form_intake_submission_spec.rb
bundle exec rspec spec/lib/form_intake/
```

### Integration Tests
```bash
bundle exec rspec spec/sidekiq/form_intake/submit_form_data_job_spec.rb
```

### VCR Cassettes
Real API interactions recorded for deterministic testing.

---

## Rollout Plan

See **[ROLLOUT-STRATEGY.md](./ROLLOUT-STRATEGY.md)** for full plan.

**Phases**:
1. ✅ **Phase 1**: Database foundation (Complete)
2. 🚧 **Phase 2**: Integration layer (In Progress)
3. 📋 **Phase 3**: Pilot with 1 form (21P-601)
4. 📋 **Phase 4**: Expand to all forms

---

## Development Status

### Phase 1 (Complete)
- ✅ Database migration
- ✅ FormIntakeSubmission model
- ✅ Associations
- ✅ Feature flags
- ✅ Unit tests

### Phase 2 (In Progress)
- 🚧 Service client
- 🚧 Sidekiq job
- 🚧 Mapper registry
- 🚧 Form mappers
- 🚧 Integration tests
- 🚧 Callback trigger

### Phase 3 (Planned)
- 📋 Pilot with 21P-601
- 📋 Monitor and iterate
- 📋 Documentation updates

---

## Support

**Team**: Backend Review Group  
**Slack**: `#benefits-simple-forms`  
**CODEOWNERS**: `@department-of-veterans-affairs/backend-review-group`

---

## References

- [GCIO API Documentation](https://internal-link-here)
- [Lighthouse Benefits Intake](https://developer.va.gov/explore/api/benefits-intake)
- [fwdproxy Setup](https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/fwdproxy.md)
- [Flipper Feature Flags](https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/flipper.md)
