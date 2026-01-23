# Play: Preserve Cause Chains

## Detect
Patterns to flag in code reviews:
- `raise "error: #{e}"` - creates RuntimeError, destroys original exception type and backtrace
- `raise ServiceException.new(e.message)` - only passes string, loses exception object
- `raise ServiceException.new(e.response)` without `cause: e` - loses original stack trace
- Any `raise NewException.new(...)` that doesn't include `cause: e`

## Fix
```ruby
# Bad: Destroys exception type, backtrace, and cause chain
rescue => e
  raise "error: #{e}"
end

# Bad: Missing cause parameter
rescue Faraday::ClientError => e
  raise BenefitsClaims::ServiceException.new(e.response)
end

# Good: Preserves full exception chain
rescue Faraday::ClientError => e
  raise BenefitsClaims::ServiceException.new(
    e.response,
    cause: e  # Preserves original exception with full stack trace
  )
end

# Good: Re-raise if not adding context
rescue BGS::Error => e
  raise  # Original exception preserved
end
```

## Why
Without `cause:`, APM shows only the wrapper exception. Original error type, HTTP status, and failure location are lost. Can't distinguish timeout from 404 from bug.
