# Play: Don't Catch, Log, and Re-raise

## Detect
Patterns to flag in code reviews:
- `rescue => e; Rails.logger.error(e); raise` - duplicates APM telemetry
- `Rails.logger.error e.backtrace.join("\n")` - APM already captures backtraces
- Catch and re-raise without adding meaningful context
- Manual exception logging when exception will propagate to APM anyway

## Fix
```ruby
# Bad: Manual backtrace logging duplicates APM
rescue => e
  Rails.logger.error "Controller error: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")  # APM already has this
  render json: { error: 'Failed' }, status: :internal_server_error
end

# Good: Let APM capture it naturally
def index
  @cemeteries = CemeteryService.all
  render json: @cemeteries
  # Exception propagates to Rails error handler -> APM captures automatically
end

# Good: Only catch when adding meaningful context
rescue CemeteryService::UpstreamError => e
  raise Common::Exceptions::ServiceUnavailable.new(
    detail: "NCA cemetery database unavailable: #{e.message}"
  )
end

# Good: Use Lighthouse::ServiceException for Faraday errors
rescue Faraday::ClientError, Faraday::ServerError => e
  Lighthouse::ServiceException.send_error(e, self.class.to_s.underscore, client_id, url)
end
```

**Rule:** If you're not adding context, don't catch it. APM captures exceptions automatically.

## Why
One exception generates two telemetry entries (manual log + APM). Engineer sees two signals, thinks two failures. Time wasted correlating duplicates.
