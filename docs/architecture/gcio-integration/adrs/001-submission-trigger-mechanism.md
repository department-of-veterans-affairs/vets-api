# ADR-001: Submission Trigger Mechanism for GCIO Form Intake Integration

## Context

When a form is successfully processed by Lighthouse Benefits Intake (status changes to `vbms`), we need to trigger the submission of form data to the GCIO API. The system must:

1. Detect when Lighthouse processing completes successfully
2. Initiate GCIO submission without blocking other operations
3. Handle the trigger reliably even under failure scenarios
4. Maintain separation of concerns between Lighthouse and GCIO integrations

### Current System Behavior

The existing `BenefitsIntakeStatusJob` polls Lighthouse daily and updates `FormSubmissionAttempt` records. When a submission reaches `vbms` status:

```ruby
# In BenefitsIntakeStatusJob
event :vbms do
  after do
    simple_forms_enqueue_result_email if should_send_simple_forms_email
  end
  transitions from: :pending, to: :vbms
  transitions from: :success, to: :vbms
end
```

The system uses AASM (state machine) callbacks to trigger side effects.

## Decision

**Use AASM `after_transition` callback on the `vbms!` event** to trigger GCIO submission.

### Implementation Approach

1. **Create a dedicated handler class** (`FormIntake::SubmissionHandler`) that responds to the state transition
2. **Register the handler** as an AASM callback in `FormSubmissionAttempt`
3. **Handler enqueues** a Sidekiq job (`FormIntake::SubmitFormDataJob`) for async processing
4. **Configuration-driven** - use Flipper feature flags to control which forms trigger GCIO submissions

```ruby
# In FormSubmissionAttempt model
event :vbms do
  after do
    simple_forms_enqueue_result_email if should_send_simple_forms_email
    FormIntake::SubmissionHandler.new(self).handle if should_submit_to_gcio?
  end
  transitions from: :pending, to: :vbms
  transitions from: :success, to: :vbms
end

def should_submit_to_gcio?
  FORM_INTAKE_ENABLED_FORMS.include?(form_submission.form_type) &&
    Flipper.enabled?(:form_intake_integration, user_account)
end
```

## Alternatives Considered

### Alternative 1: Modify BenefitsIntakeStatusJob Directly

**Approach**: Add GCIO submission logic directly in the polling job.

**Rejected because**:
- Violates single responsibility principle
- Couples Lighthouse status polling with GCIO submission
- Makes the polling job harder to test and maintain
- Reduces reusability if we need to trigger GCIO from other sources

### Alternative 2: Database Triggers

**Approach**: Use PostgreSQL triggers to detect state changes and enqueue jobs.

**Rejected because**:
- Moves business logic into database layer
- Reduces testability and visibility
- Goes against Rails conventions
- Harder to debug and maintain
- No access to Ruby ecosystem (Flipper, logging, etc.)

### Alternative 3: Event Bus / Pub-Sub Pattern

**Approach**: Introduce an event bus (e.g., Kafka, SNS) for state change events.

**Rejected because**:
- Over-engineered for the current requirement
- Introduces new infrastructure dependencies
- Increases operational complexity
- No existing event bus infrastructure in vets-api
- AASM callbacks provide sufficient decoupling

### Alternative 4: Polling GCIO Eligibility

**Approach**: Create a separate job that polls for `vbms` status records needing GCIO submission.

**Rejected because**:
- Introduces unnecessary delay
- More complex than leveraging existing state machine
- Requires maintaining additional "sync state" logic
- Less real-time than callback approach

## Consequences

### Positive

- **Leverages existing patterns**: Uses AASM callbacks already present in the codebase
- **Separation of concerns**: Handler class isolates GCIO logic
- **Testable**: Can test handler and job independently
- **Configurable**: Feature flags provide fine-grained control
- **Reliable**: State transitions are atomic within database transactions
- **Observable**: Clear entry point for monitoring and logging
- **Non-blocking**: Sidekiq job ensures async processing

### Negative

- **Callback complexity**: Additional callback increases model complexity
- **Order dependency**: Relies on callback execution order if multiple callbacks exist
- **Transaction coupling**: Handler execution tied to database transaction success

### Mitigations

- **Clear naming**: `FormIntake::SubmissionHandler` makes purpose explicit
- **Documentation**: ADR and inline comments explain the flow
- **Testing**: Comprehensive tests for callback behavior
- **Feature flags**: Can disable quickly if issues arise
- **Monitoring**: Add metrics for handler invocation and job enqueuing

## Implementation Notes

### Configuration

```ruby
# config/initializers/form_intake_integration.rb
FORM_INTAKE_ENABLED_FORMS = %w[
  21-526EZ
  21-0966
  # Add other forms as needed
].freeze
```

### Feature Flag

```yaml
# config/features.yml
form_intake_integration:
  actor_type: user_account
  description: Enable GCIO API integration for form submissions
```

### Monitoring

```ruby
# In handler
StatsD.increment('gcio.submission_handler.invoked', tags: ["form_type:#{form_type}"])
StatsD.increment('gcio.submission_handler.job_enqueued', tags: ["form_type:#{form_type}"])
```

