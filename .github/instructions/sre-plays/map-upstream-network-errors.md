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

# Good: Use Lighthouse::ServiceException for automatic status mapping and logging
def handle_error(error, lighthouse_client_id, endpoint)
  Lighthouse::ServiceException.send_error(
    error,
    self.class.to_s.underscore,
    lighthouse_client_id,
    "#{config.base_api_path}/#{endpoint}"
  )
end

rescue Faraday::ClientError, Faraday::ServerError => e
  handle_error(e, lighthouse_client_id, endpoint)

# Good: Or use BenefitsClaims::ServiceException pattern
# Note: TimeoutError has no response, so handle it explicitly first
rescue Faraday::TimeoutError
  raise BenefitsClaims::ServiceException.new({ status: 504 }), 'Lighthouse Error'
rescue Faraday::ClientError, Faraday::ServerError => e
  raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'

# Good: Direct exception raises (note: GatewayTimeout takes NO arguments)
rescue Faraday::TimeoutError
  raise Common::Exceptions::GatewayTimeout  # 504
rescue Faraday::ConnectionFailed
  raise Common::Exceptions::ServiceUnavailable.new(detail: 'Connection failed')  # 503
rescue Faraday::ServerError => e
  raise Common::Exceptions::BadGateway.new(detail: "Upstream error: #{e.response[:status]}")  # 502
```

**Mapping:**
- Timeout → 504 Gateway Timeout
- Connection/DNS failure → 503 Service Unavailable
- Upstream 5xx → 502 Bad Gateway (with upstream_status)

## Why
Upstream timeout returning 500 alerts our team for their slowness. Metrics blame us for their issues. Clients treat 500 as non-retryable when 503/504 would auto-retry.
