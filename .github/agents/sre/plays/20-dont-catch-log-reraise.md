# Play 20: Don't Catch, Log, and Re-raise (No Double Handling)

## Context
A single exception generates two telemetry entries -- one from the manual log and one from APM -- creating duplicate backtraces with zero additional value. During an incident, an engineer sees two error signals and thinks two separate failures occurred, wasting time correlating what is actually a single exception. Every exception creates two to three redundant log lines even though APM already captures the backtrace, params, user, and timing automatically. The manual log adds no context that APM does not already have, so the duplication is pure noise that drowns real issues.

## Applies To
- `app/controllers/**/*.rb`
- `app/sidekiq/**/*.rb`
- `app/models/**/*.rb`
- `modules/*/app/controllers/**/*.rb`
- `modules/*/app/models/**/*.rb`
- `modules/*/app/sidekiq/**/*.rb`
- `lib/**/*.rb`

## Investigation Steps
1. Read the full rescue block to determine whether the log adds ANY context not already captured by APM (request/response payloads, business context, correlation IDs). If it does, this may not be a violation.
2. Check whether the rescue block re-raises the same exception or wraps it in a new typed exception. Re-raising the same exception after logging is the violation. Wrapping with a new exception and cause chain is acceptable.
3. Determine whether the code is at a controller boundary where the ExceptionHandling concern would catch the exception automatically. If so, the entire rescue block may be unnecessary.
4. Check for StatsD metric calls in the rescue block -- these are acceptable and should be preserved even if the logging is removed.
5. Verify that removing the rescue block would not change the HTTP response behavior (e.g., if the rescue renders a custom error page).

## Severity Assessment
- **CRITICAL:** Catch-log-reraise in code handling PII, PHI, or financial data where log duplication may expose sensitive fields
- **HIGH:** Catch-log-reraise in controller actions or service layers calling external APIs -- duplicates telemetry during incidents
- **HIGH:** Manual backtrace logging in any rescue block -- always duplicates APM
- **MEDIUM:** Catch-log-reraise in internal utility code where log volume impact is lower

## Golden Patterns

### Do
Catch only when adding meaningful context or converting to a typed exception:
```ruby
rescue CemeteryService::UpstreamError => e
  raise Common::Exceptions::ServiceUnavailable.new(
    detail: "NCA cemetery database unavailable",
    cause: e  # Preserves original exception for APM
  )
end
```

Wrap with `cause: e` and re-raise a new typed exception when adding context:
```ruby
raise AppSpecificError.new("meaningful context", cause: e)
```

Emit metrics (StatsD counters) for retry attempts instead of logs:
```ruby
rescue Faraday::TimeoutError => e
  StatsD.increment("service.retry_attempt")
  raise
end
```

### Don't
Log and re-raise the same exception -- let APM record it once:
```ruby
# BAD -- duplicates telemetry
rescue => e
  Rails.logger.error("Something failed: #{e.message}")
  raise
end
```

Manually log backtraces (`e.backtrace.join`) -- APM captures them automatically:
```ruby
# BAD -- APM already has the full backtrace
rescue => e
  Rails.logger.error e.backtrace.join("\n")
  raise
end
```

Log an exception then re-raise without adding any new context:
```ruby
# BAD -- zero information added beyond what APM captures
rescue StandardError => e
  logger.warn("failed: #{e}")
  raise e
end
```

## Anti-Patterns

### Cemeteries Controller - Catch, Log, and Render
**Anti-pattern:**
```ruby
rescue => e
  Rails.logger.error "Cemetery controller error: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")  # Manual backtrace logging
  render json: { error: 'Unable to load cemetery data' }, status: :internal_server_error
end
```
**Problem:** Catches the exception and manually logs backtrace via `e.backtrace.join("\n")`, duplicating what APM captures automatically. `Rails.logger.error` with `e.message` duplicates the exception message APM already records. Renders a generic error response instead of letting ExceptionHandling produce a standardized response. Zero value added -- APM has backtrace, params, user, and timing automatically.

**Corrected:**
```ruby
# Let APM capture it naturally - no rescue needed
def index
  @cemeteries = CemeteryService.all
  render json: @cemeteries
  # Exception propagates to Rails error handler -> APM captures automatically
end

# OR if adding meaningful context:
rescue CemeteryService::UpstreamError => e
  raise Common::Exceptions::ServiceUnavailable.new(
    detail: "NCA cemetery database unavailable",
    cause: e  # Preserves original exception for APM
  )
end
```

## Finding Template
**Don't catch, log, and re-raise** | `HIGH`

`{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

**Why this matters:** This rescue block logs the exception and then re-raises it, generating two telemetry entries for a single failure. APM automatically captures the exception class, message, full backtrace, and request context. The manual log adds zero information and creates noise during incidents.

**Suggested fix:**
```ruby
{{suggested_code}}
```

- [ ] No manual backtrace logging (`e.backtrace.join` removed)
- [ ] One exception generates one signal in APM (not two)
- [ ] If wrapping, cause chain preserved with `cause: e`

[Play: Don't catch, log, and re-raise](plays/dont-catch-log-reraise.md)

## Verify Commands
```bash
# No manual backtrace logging remains in changed file
grep -On '\.backtrace\.join' {{file_path}} && exit 1 || exit 0

# No catch-log-reraise pattern remains
grep -Pzn 'rescue.*\n.*logger\.(error|warn).*\n.*raise\b' {{file_path}} && exit 1 || exit 0

# Run specs for changed file
bundle exec rspec {{spec_path}}

# RuboCop passes for changed file
bundle exec rubocop {{file_path}}
```

## Related Plays
- Play: bare-rescue (complementary)
- Play: prefer-structured-logs (complementary)
