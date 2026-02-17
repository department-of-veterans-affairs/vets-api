# ADR-001: Trigger GCIO Submission Immediately After Lighthouse Upload

## Context

When a PDF is uploaded to Lighthouse Benefits Intake, structured JSON data must be sent to GCIO immediately. IBM Mail Automation queries GCIO for this data when processing PDFs into VBMS. If the data isn't ready, IBM processes without it.

**Critical timing requirement**: Data must be at GCIO within seconds, not days.

## Decision

**Trigger GCIO submission immediately after successful Lighthouse PDF upload.**

For SavedClaim forms: Add trigger in `Lighthouse::SubmitBenefitsIntakeClaim` job after upload succeeds.  
For Simple Forms: Use `FormSubmissionAttempt.after_commit` callback.

Both enqueue `FormIntake::SubmitFormDataJob` (async, non-blocking).

```ruby
# After Lighthouse success
if response.success?
  FormIntake::SubmitFormDataJob.perform_async(form_submission_id, lighthouse_uuid)
end
```

## Alternatives Considered

**After vbms status (polling)**: Rejected - Too late (days), IBM already processed PDF  
**Synchronous call**: Rejected - Blocks Lighthouse job, couples failures  
**Before Lighthouse upload**: Rejected - No UUID available for correlation  

## Consequences

**Positive**:
- Data ready in seconds (not days)
- Non-blocking (async job)
- Independent failures (GCIO doesn't affect Lighthouse)
- UUID available for correlation

**Negative**:
- Adds trigger logic to Lighthouse job
- More test scenarios

**Mitigation**: Wrap in rescue block, feature flags for control
