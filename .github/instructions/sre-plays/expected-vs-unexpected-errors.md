# Play: Expected vs Unexpected Errors

## Detect
Patterns to flag in code reviews:
- `span.set_error(e)` for 4xx responses - floods APM with expected errors
- `Rails.logger.error` for validation failures (422) - should be warn
- Manual span tagging in controllers for validation errors
- Treating all exceptions the same in observability

## Fix
```ruby
# Bad: Marks validation error (expected) as APM error
rescue ValidationError => e
  span = Datadog::Tracing.active_span
  span.set_error(e)  # Floods APM dashboard
  raise Common::Exceptions::UnprocessableEntity.new(detail: e.message)
end

# Good: Only mark 5xx as APM errors
def report_exception(exception, status_code)
  if status_code >= 500
    Rails.logger.error('System failure', exception: exception)
    Datadog::Tracing.active_span&.set_error(exception)
  else
    Rails.logger.warn('Client error', exception: exception)
    # No span.set_error - expected business outcome
  end
end

# Best: Let ExceptionHandling concern decide (no manual APM tagging)
def upload
  form = service.create_form(params)
  render json: form, status: :created
  # Validation errors propagate to ExceptionHandling, which handles logging/APM
end
```

**Rule:**
- Expected (4xx): `Rails.logger.warn`, NO `span.set_error`
- Unexpected (5xx): `Rails.logger.error`, YES `span.set_error`

## Why
APM shows 10,000 errors. 9,500 are 422 validations. Real 500s buried in noise. On-call paged for user typos. Alert fatigue.
