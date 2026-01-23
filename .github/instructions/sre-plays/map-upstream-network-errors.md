# Play: Map Upstream Network Errors Correctly

## Detect
Patterns to flag in code reviews:
- `rescue Faraday::Error => e; raise InternalServerError` - all network errors become 500
- `rescue Faraday::ClientError, Faraday::ServerError` with same handler - loses diagnostic precision
- Any upstream error returning 500 - blames our team for their issues
- Missing upstream_status in error metadata

## Fix
```ruby
# Bad: All Faraday errors become 500 (our fault)
rescue Faraday::ClientError, Faraday::ServerError => e
  raise Common::Exceptions::InternalServerError, exception: e
end

# Good: Specific status codes for each failure type
rescue Faraday::TimeoutError => e
  raise Common::Exceptions::GatewayTimeout.new(cause: e)  # 504

rescue Faraday::ConnectionFailed => e
  raise Common::Exceptions::ServiceUnavailable.new(cause: e)  # 503

rescue Faraday::ServerError => e
  raise Common::Exceptions::BadGateway.new(
    detail: 'Upstream service error',
    meta: { upstream_status: e.response[:status] },
    cause: e
  )  # 502
```

**Mapping:**
- Timeout → 504 Gateway Timeout
- Connection/DNS failure → 503 Service Unavailable
- Upstream 5xx → 502 Bad Gateway (with upstream_status)

## Why
Upstream timeout returning 500 alerts our team for their slowness. Metrics blame us for their issues. Clients treat 500 as non-retryable when 503/504 would auto-retry.
