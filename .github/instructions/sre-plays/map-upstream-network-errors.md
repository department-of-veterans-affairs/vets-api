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
  raise Common::Exceptions::InternalServerError.new(e)
end

# Good: Specific status codes for each failure type
rescue Faraday::TimeoutError => e
  # Map network timeout to 504 Gateway Timeout
  raise Common::Exceptions::GatewayTimeout.new  # 504

rescue Faraday::ConnectionFailed => e
  # Map connection/DNS failure to 503 Service Unavailable
  raise Common::Exceptions::ServiceUnavailable.new  # 503

rescue Faraday::ServerError => e
  # Map upstream 5xx to 502 Bad Gateway, including upstream status in errors payload
  raise Common::Exceptions::BadGateway.new(
    detail: 'Upstream service error',
    errors: [{ upstream_status: e.response[:status] }]
  )  # 502
```

**Mapping:**
- Timeout → 504 Gateway Timeout
- Connection/DNS failure → 503 Service Unavailable
- Upstream 5xx → 502 Bad Gateway (with upstream_status)

## Why
Upstream timeout returning 500 alerts our team for their slowness. Metrics blame us for their issues. Clients treat 500 as non-retryable when 503/504 would auto-retry.
