# Play 02: Always Preserve the Cause Chain When Wrapping Exceptions

## Context
APM shows "ServiceException at line 46" but the original Faraday::ServerError is lost and the HTTP 503 status becomes invisible. The stack trace shows only the re-raise line, destroying the root cause location so you cannot find where the connection failed. Sidekiq sees a RuntimeError instead of a TimeoutError, applies the wrong retry strategy, and the job fails permanently. When 500 errors spike, you cannot tell a timeout from a 404 from a bug, requiring manual log grep that wastes hours.

## Applies To
- `app/controllers/**/*.rb`
- `app/sidekiq/**/*.rb`
- `app/models/**/*.rb`
- `modules/*/app/controllers/**/*.rb`
- `modules/*/app/models/**/*.rb`
- `modules/*/app/sidekiq/**/*.rb`
- `lib/**/*.rb`

## Investigation Steps
1. Read the full method containing the rescue block to understand what exception is being caught and what new exception is being raised.
2. Identify the exception class being raised -- does its constructor accept a `cause:` keyword argument? If not, the class itself may need to be updated before the fix can be applied.
3. Check if the code uses `raise "string"` pattern -- this always creates a new RuntimeError and is never correct. The fix is `raise` without arguments or a typed exception with `cause:` passing the caught exception.
4. Determine whether the rescue block catches specific exceptions or uses bare rescue. If bare rescue, the cause chain fix should be combined with narrowing the rescue clause (see Play 03: Never Use Broad Rescues).
5. Check if Sidekiq retry behavior depends on the exception type. If so, preserving the original class is critical for correct retry strategy. Do not suggest adding `cause: e` without first verifying that the exception constructor accepts it. Read the exception class definition if needed.

## Severity Assessment
- **CRITICAL**: Cause chain lost in code handling PII, PHI, or benefits claims data
- **CRITICAL**: Stringified re-raise in Sidekiq job where retry strategy depends on exception type
- **CRITICAL**: Cause chain lost in service layer calling external APIs (BGS, MPI, Lighthouse) -- APM blackout for upstream errors
- **HIGH**: Exception wrapped without cause: in controller handling user-facing requests
- **HIGH**: Cause chain lost in code where HTTP status codes must propagate for correct error responses
- **MEDIUM**: Cause chain lost in internal utility with no external dependencies or retry behavior

## Golden Patterns

### Do
Wrap with context while preserving the chain:
```ruby
raise ServiceException.new("BGS failed", cause: e)
```

Re-raise the original exception unchanged when no context is needed:
```ruby
raise  # no arguments -- Ruby automatically preserves the original exception
```

### Don't
Never create a RuntimeError via string interpolation (loses class, backtrace, cause chain):
```ruby
# BAD
raise "error: #{e}"
```

Never extract only the message string (loses everything else):
```ruby
# BAD
raise ServiceException.new(e.message)
```

Never wrap without `cause: e` (HTTP status lost from APM):
```ruby
# BAD
raise ServiceException.new(e.response)
```

## Anti-Patterns

### Lighthouse Benefits Claims Service
**Anti-pattern:**
```ruby
rescue Faraday::ClientError, Faraday::ServerError => e
  raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
  # Missing cause: parameter -- original Faraday exception lost
end
```
**Problem:** Missing `cause: e` -- APM sees only `ServiceException: Lighthouse Error` at line 46. The original `Faraday::ServerError` with its 503 status, timeout location, and connection details is destroyed. You cannot distinguish a 404 from a 503 from a network timeout.

**Corrected:**
```ruby
rescue Faraday::ClientError, Faraday::ServerError => e
  raise BenefitsClaims::ServiceException.new(
    e.response,
    'Lighthouse Error',
    cause: e  # Preserves original exception with full stack trace
  )
end
```

### Mobile Dependents Controller
**Anti-pattern:**
```ruby
rescue => e  # Catches ALL exceptions (typos, timeouts, DB errors)
  raise Common::Exceptions::BackendServiceException.new(
    nil,
    detail: e.message  # Only string -- loses stack trace, exception type, cause chain
  )
end
```
**Problem:** `e.message` extracts only the string -- original exception class, backtrace, and cause chain are gone. APM sees `BackendServiceException` at controller.rb:12 for every error. A BGS timeout looks identical to a `NoMethodError` from a typo.

**Corrected:**
```ruby
rescue BGS::ServiceError => e
  raise Common::Exceptions::BackendServiceException.new(
    'BGS',
    detail: 'BGS service unavailable',
    cause: e  # Preserves original exception object with stack trace
  )
rescue ActiveRecord::RecordNotFound => e
  raise Common::Exceptions::RecordNotFound.new(
    detail: "Dependent not found",
    cause: e  # Preserves ActiveRecord exception with query details
  )
end
```

### Income Limit Import Jobs -- Stringified Re-raise
**Anti-pattern:**
```ruby
def perform
  # ... CSV import logic ...
rescue => e
  raise "error: #{e}"
  # Creates NEW RuntimeError -- original class, backtrace, and cause chain destroyed
end
```
**Problem:** `raise "error: #{e}"` creates a new `RuntimeError` with a flat string. The original exception class is gone, the backtrace points to this line only, and Sidekiq picks the wrong retry strategy because it sees `RuntimeError` instead of `Faraday::ConnectionFailed`. Found in 5 income limit Sidekiq jobs as a systemic copy-paste pattern.

**Corrected:**
```ruby
def perform
  # ... CSV import logic ...
rescue => e
  raise  # Re-raises original exception with full context
  # Or if adding context:
  raise ImportError.new("CSV import failed", cause: e)
end
```

## Finding Template
**Always Preserve the Cause Chain When Wrapping Exceptions** | `CRITICAL`

`{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

**Why this matters:** Without the cause chain, APM shows only the wrapper
exception at the re-raise line. The original error's stack trace, HTTP status
code, and exception class are lost. Engineers cannot determine root cause
without manual log analysis. Sidekiq retry strategies may apply the wrong
policy when the original exception type is destroyed.

**Suggested fix:**
```ruby
{{suggested_code}}
```

**Verify:**
- [ ] `cause:` passed to exception constructor with the caught exception (or `raise` without arguments used)
- [ ] No `raise "error: #{e}"` patterns remain
- [ ] APM traces show full chain: wrapper -> original exception
- [ ] Stack trace shows original failure location

[Play: Always Preserve the Cause Chain](plays/preserve-cause-chains.md)

## Verify Commands
- `grep -On 'raise\s+".*#\{' {{file_path}}` -- No stringified re-raise remains
- `grep -On 'raise\s+\w+\.new\(.*\.message\)' {{file_path}}` -- No message-only wrap remains
- `bundle exec rspec {{spec_path}}` -- Run specs for changed file
- `bundle exec rubocop {{file_path}}` -- RuboCop passes for changed file

## Related Plays
- bare-rescue (complementary)
- prefer-typed-exceptions (complementary)
