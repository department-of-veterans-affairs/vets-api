# Play 09: Expected vs Unexpected Errors (Logging + APM)

## Context
APM shows 10,000 errors, but 9,500 are 422 validation failures and only 500 are real server errors, burying genuine issues in noise. Rails logs validation failures at ERROR level, firing alerts and paging on-call engineers for user typos rather than system failures, causing alert fatigue. ExceptionHandling marks most exceptions as APM errors without distinguishing expected 4xx from unexpected 5xx, because the `skip_sentry_exception?` check only filters a narrow list of known exceptions.

## Applies To
- `app/controllers/concerns/exception_handling.rb`
- `app/controllers/**/*.rb`
- `modules/*/app/controllers/**/*.rb`

## Investigation Steps
1. Read `app/controllers/concerns/exception_handling.rb` fully, especially the `report_mapped_exception` method, to understand the current flow from exception to APM span tagging.
2. Identify whether `va_exception.status_code` is available in the method scope. The fix depends on being able to check the status code before calling `set_error`.
3. Check if the violation is in ExceptionHandling (centralized fix) or in a specific controller (remove manual span tagging, let ExceptionHandling decide).
4. If in a controller, check whether the controller manually tags spans AND re-raises to ExceptionHandling. If so, the fix is to remove manual tagging, not to add status checks in the controller.
5. Verify whether the controller's exception will flow to ExceptionHandling. If the controller catches and does not re-raise, that is a separate issue. Do not suggest adding status checks to individual controllers. The fix belongs in ExceptionHandling.

## Severity Assessment
- **CRITICAL:** `set_error` called for all exceptions in ExceptionHandling concern (affects entire application)
- **CRITICAL:** APM error rate includes 4xx client errors making SLI metrics useless
- **HIGH:** Manual `span.set_error` in controller rescue block for expected error types
- **HIGH:** Manual `span.set_tag` with error metadata in controller (violates layering)
- **MEDIUM:** `Rails.logger.error` used for 4xx validation failures (should be warn)

## Golden Patterns

### Do
Log expected errors (4xx) as WARN -- they are normal business outcomes:
```ruby
Rails.logger.warn('Validation failed', { status: 422, message: exception.message })
```

Log unexpected errors (5xx) as ERROR and call `span.set_error`:
```ruby
if va_exception.status_code >= 500
  Datadog::Tracing.active_span&.set_error(exception)
end
```

Implement status-aware error reporting in ExceptionHandling:
```ruby
def report_mapped_exception(exception, va_exception)
  log_level = va_exception.status_code >= 500 ? :error : :warn

  Rails.logger.public_send(log_level, 'Exception occurred', {
    exception: exception.class.name,
    message: exception.message,
    status: va_exception.status_code
  })

  Raven.capture_exception(exception) if va_exception.status_code >= 500

  if va_exception.status_code >= 500
    Datadog::Tracing.active_span&.set_error(exception)
    request.env[Datadog::Tracing::Contrib::Rack::Ext::RACK_ENV_REQUEST_SPAN]&.set_error(exception)
  end
end
```

### Don't
Never call `span.set_error` for 4xx exceptions -- this floods APM with expected business outcomes:
```ruby
# BAD: marks ALL exceptions as APM errors
Datadog::Tracing.active_span&.set_error(exception)
request.env[Datadog::Tracing::Contrib::Rack::Ext::RACK_ENV_REQUEST_SPAN]&.set_error(exception)
```

Never manually tag spans with error metadata in controllers -- let ExceptionHandling decide:
```ruby
# BAD: controller doing APM tagging that belongs in ExceptionHandling
span.set_tag('error.type', 'record_invalid')
span.set_tag('error.specific_reason', 'record_invalid')
```

## Anti-Patterns

### ExceptionHandling set_error Issue
**Anti-pattern:**
```ruby
def report_mapped_exception(exception, va_exception)
  # ... logging ...

  # Calls set_error for ALL exceptions including expected errors
  Datadog::Tracing.active_span&.set_error(exception)
  request.env[Datadog::Tracing::Contrib::Rack::Ext::RACK_ENV_REQUEST_SPAN]&.set_error(exception)
end
```
**Problem:** Calls `set_error` for ALL exceptions regardless of status code (4xx and 5xx alike). APM dashboards flooded with validation failures. Cannot distinguish real system failures from expected client errors. False alerts wake on-call for user validation errors.

**Corrected:**
```ruby
def report_mapped_exception(exception, va_exception)
  log_level = va_exception.status_code >= 500 ? :error : :warn

  Rails.logger.public_send(log_level, 'Exception occurred', {
    exception: exception.class.name,
    message: exception.message,
    status: va_exception.status_code
  })

  Raven.capture_exception(exception) if va_exception.status_code >= 500

  if va_exception.status_code >= 500
    Datadog::Tracing.active_span&.set_error(exception)
    request.env[Datadog::Tracing::Contrib::Rack::Ext::RACK_ENV_REQUEST_SPAN]&.set_error(exception)
  end
end
```

### Manual Span Tagging in Controller
**Anti-pattern:**
```ruby
rescue service::RecordInvalidError => e
  span = Datadog::Tracing.active_span
  span.set_tag('error.type', 'record_invalid')
  span.set_tag('error.specific_reason', 'record_invalid')
  span.set_tag('error.original_class', e.class.name)
  raise Common::Exceptions::ValidationErrors, e.record
end
```
**Problem:** Violates layering -- controller validates (correct) but also does APM tagging (should be in ExceptionHandling). Validation errors (422) are expected and should not be tagged as APM errors. Creates inconsistency across controllers.

**Corrected:**
```ruby
# Just validate and throw (no rescue, no span tagging)
def upload
  form = service.create_form(params)
  # If validation fails, service raises Common::Exceptions::ValidationErrors
  # ExceptionHandling catches it, logs WARN, returns 422, does NOT call span.set_error
  render json: form, status: :created
end
```

## Finding Template
**Expected vs Unexpected Errors (Logging + APM)** | `CRITICAL`

`{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

**Why this matters:** Calling `span.set_error` for expected errors (4xx) floods
APM with validation failures. On-call gets paged for "user entered invalid email."
Real 500s are buried under thousands of 422s. SLI error rate shows 95% when the
system is healthy.

**The Rule:**
- Expected errors (4xx) -> `Rails.logger.warn` + NO `span.set_error`
- Unexpected errors (5xx) -> `Rails.logger.error` + YES `span.set_error`

**Suggested fix:**
```ruby
{{suggested_code}}
```

**Verify:**
- [ ] `span.set_error` called only when `status_code >= 500`
- [ ] 4xx validation errors logged as WARN, not marked as APM errors
- [ ] No manual span tagging in controllers
- [ ] APM error rate reflects only 5xx system failures
- [ ] 4xx spike monitoring in place (Error Code Paradox)

[Play: Expected vs Unexpected Errors](plays/expected-vs-unexpected-errors.md)

## Verify Commands
```bash
# No unconditional set_error in ExceptionHandling
grep -On 'set_error\(' app/controllers/concerns/exception_handling.rb | grep -v 'status_code.*>=.*500' | grep -v '#' && exit 1 || exit 0

# No manual span.set_error in controllers
grep -rn 'span.*set_error\|set_tag.*error' app/controllers/ modules/*/app/controllers/ --include='*.rb' | grep -v exception_handling | grep -v '#' && exit 1 || exit 0

# Run specs for ExceptionHandling
bundle exec rspec spec/controllers/concerns/exception_handling_spec.rb

# RuboCop passes for ExceptionHandling
bundle exec rubocop app/controllers/concerns/exception_handling.rb
```

## Related Plays
- Play: Classify Errors (prerequisite)
- Play: Prefer Structured Logs (complementary)
- Play: Don't Build Module-Specific Frameworks (complementary)
