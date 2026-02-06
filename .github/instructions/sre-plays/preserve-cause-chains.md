# Play: Preserve Error Context When Wrapping Exceptions

## Detect
Patterns to flag in code reviews:
- `raise "error: #{e}"` - creates RuntimeError, destroys original exception type and backtrace
- `raise ServiceException.new(e.message)` - only passes string, loses HTTP status and response
- Catching and re-raising without using proper exception mapping patterns
- Not using `Lighthouse::ServiceException.send_error` for Faraday errors

## Fix
```ruby
# Bad: Destroys exception type, backtrace, and response data
rescue => e
  raise "error: #{e}"
end

# Bad: Loses HTTP status from response
rescue Faraday::ClientError => e
  raise Common::Exceptions::ServiceError.new(detail: e.message)
end

# Good: Use Lighthouse::ServiceException to preserve context and map status
rescue Faraday::ClientError, Faraday::ServerError => e
  Lighthouse::ServiceException.send_error(
    e,
    self.class.to_s.underscore,
    lighthouse_client_id,
    url
  )
  # This logs the error with full context and raises the appropriate
  # Common::Exceptions class based on HTTP status code

# Good: Use BenefitsClaims::ServiceException to map response status
rescue Faraday::TimeoutError
  raise BenefitsClaims::ServiceException.new({ status: 504 }), 'Lighthouse Error'
rescue Faraday::ClientError, Faraday::ServerError => e
  raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
  # Maps e.response[:status] to appropriate Common::Exceptions class

# Good: Re-raise without wrapping if not adding context
rescue BGS::Error
  raise  # Original exception preserved with full backtrace
end
```

## Why
Wrapping exceptions without preserving response data loses HTTP status codes needed for proper error classification. `Lighthouse::ServiceException.send_error` logs to Sentry with full context and maps the response's HTTP status to the appropriate exception class (e.g., 502→BadGateway, 503→ServiceUnavailable). Note: `Faraday::TimeoutError` has no response, so handle it explicitly before calling `send_error`.
