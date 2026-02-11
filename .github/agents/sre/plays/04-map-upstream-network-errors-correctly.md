# Play 04: Map Upstream Network Errors Correctly

## Context
When an upstream timeout falls through as a generic 500, metrics blame our team and alerts page us, even though the actual problem is the upstream service's slow response. The client sees 500 and will not retry because the HTTP spec treats 500 as non-retryable, but a 504 would signal a gateway timeout and trigger automatic retries. APM shows generic 500 errors with no way to distinguish our code bugs from upstream timeouts, requiring manual log grep to identify the root cause. SRE investigates our code and wastes hours when the actual problem is an upstream DNS failure that should have returned 503.

## Applies To
- `app/controllers/**/*.rb`
- `modules/*/app/controllers/**/*.rb`
- `lib/**/*.rb`
- `app/services/**/*.rb`
- `modules/*/app/services/**/*.rb`

## Investigation Steps
1. Read the full method containing the rescue block to understand which Faraday methods are called and what upstream services are contacted.
2. Identify which Faraday exception types the upstream call can raise -- TimeoutError, ConnectionFailed, ServerError, ClientError, etc.
3. Check whether the code is in a controller (boundary) or service layer. Controllers should map to HTTP status codes. Service layers may need to raise module-specific exceptions that controllers then translate.
4. Verify that `Common::Exceptions::GatewayTimeout`, `ServiceUnavailable`, and `BadGateway` are available in the module's namespace.
5. Check if the upstream response object (`e.response`) is available for the caught exception type -- `Faraday::ConnectionFailed` has no response. Do not suggest adding `meta.upstream_status` for exceptions that lack a response object (e.g., TimeoutError, ConnectionFailed).

## Severity Assessment
- **CRITICAL**: All upstream Faraday errors mapped to 500 in a controller handling veteran-facing requests
- **CRITICAL**: Upstream timeouts return 500 causing incorrect alert routing and client retry failure
- **HIGH**: Blanket Faraday catch in service layer without distinguishing timeout from connection failure
- **MEDIUM**: Upstream errors mapped to correct gateway status but missing meta.upstream_status

## Golden Patterns

### Do
Map each failure mode to its correct gateway status:
```ruby
rescue Faraday::TimeoutError => e
  raise Common::Exceptions::GatewayTimeout.new(cause: e)  # 504 -- upstream was too slow

rescue Faraday::ConnectionFailed => e
  raise Common::Exceptions::ServiceUnavailable.new(cause: e)  # 503 -- upstream is unreachable

rescue Faraday::ServerError => e
  raise Common::Exceptions::BadGateway.new(
    detail: 'Upstream service error',
    meta: { upstream_status: e.response[:status] },
    cause: e
  )  # 502 -- upstream broke
```

### Don't
Never catch all Faraday errors in one clause -- conflates failure modes:
```ruby
# BAD
rescue Faraday::ClientError, Faraday::ServerError => e
  raise Common::Exceptions::InternalServerError, exception: e
end
```

Never map upstream errors to 500 -- 500 means our code is broken, not upstream:
```ruby
# BAD
raise Common::Exceptions::InternalServerError, exception: e
```

## Anti-Patterns

### Travel Pay Claims Controller
**Anti-pattern:**
```ruby
rescue Faraday::ClientError, Faraday::ServerError => e
  raise Common::Exceptions::InternalServerError, exception: e
  # Maps ALL Faraday errors to 500 (our fault)
  # Should distinguish: timeout->504, connection->503, server->502
end
```
**Problem:** Catches both `ClientError` and `ServerError` in one clause and maps all upstream failures to 500. Metrics blame our team. Clients see 500 (non-retryable) instead of 504 (retryable) for upstream timeouts. SRE investigates our code when the actual problem is upstream.

**Corrected:**
```ruby
rescue Faraday::TimeoutError => e
  raise Common::Exceptions::GatewayTimeout.new(cause: e)  # 504

rescue Faraday::ConnectionFailed => e
  raise Common::Exceptions::ServiceUnavailable.new(cause: e)  # 503

rescue Faraday::ServerError => e
  raise Common::Exceptions::BadGateway.new(
    detail: 'Upstream service error',
    meta: { upstream_status: e.response[:status] },
    cause: e
  )
end
```

## Finding Template
**Don't let all upstream network errors fall through as 500 errors** | `CRITICAL`

`{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

**Why this matters:** Mapping all upstream errors to 500 blames our team
for upstream failures. Metrics, alerts, and on-call pages fire on the
wrong team. Clients see 500 (non-retryable) instead of 504 (retryable)
for transient upstream failures. APM cannot distinguish our code bugs
from upstream timeouts or connection failures.

**Suggested fix:**
```ruby
rescue Faraday::TimeoutError => e
  raise Common::Exceptions::GatewayTimeout.new(cause: e)  # 504
rescue Faraday::ConnectionFailed => e
  raise Common::Exceptions::ServiceUnavailable.new(cause: e)  # 503
rescue Faraday::ServerError => e
  raise Common::Exceptions::BadGateway.new(
    detail: 'Upstream service error',
    meta: { upstream_status: e.response[:status] },
    cause: e
  )
end
```

**Verify:**
- [ ] Timeouts return 504 (not 500)
- [ ] Connection failures return 503 (not 500)
- [ ] Upstream server errors return 502 with `meta.upstream_status`
- [ ] Cause chain preserved with `cause: e`
- [ ] Metrics separate our bugs (500) from upstream issues (502/503/504)

[Play: Map Upstream Network Errors Correctly](plays/map-upstream-network-errors-correctly.md)

## Verify Commands
- `grep -On 'rescue\s+Faraday::.*\n.*InternalServerError' {{file_path}}` -- No Faraday errors mapped to InternalServerError
- `grep -On 'rescue\s+Faraday::ClientError,\s*Faraday::ServerError' {{file_path}}` -- No blanket Faraday catch without distinction
- `bundle exec rspec {{spec_path}}` -- Run specs for changed file
- `bundle exec rubocop {{file_path}}` -- RuboCop passes for changed file

## Related Plays
- classify-errors (prerequisite)
- preserve-cause-chains (complementary)
