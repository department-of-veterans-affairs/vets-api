# Play: Don't Swallow Errors

## Detect
Patterns to flag in code reviews:
- `rescue => e; nil` - swallows all errors, returns nil as if nothing happened
- `rescue; false` - hides failures, returns false as if "no results"
- `rescue => e; Rails.logger.warn(...); nil` - logs but still swallows the error
- Silent retries that return nil when exhausted - data loss with zero visibility

## Fix
```ruby
# Bad: Swallows timeout, returns nil (looks like "no file number found")
def veteran_va_file_number(user)
  response = BGS::People::Request.new.find_person_by_participant_id(user:)
  response.file_number
rescue
  nil
end

# Good: Raises so APM sees it and caller knows what happened
def veteran_va_file_number(user)
  response = BGS::People::Request.new.find_person_by_participant_id(user:)
  response.file_number
rescue BGS::ServiceError, Faraday::Error => e
  raise Common::Exceptions::ServiceUnavailable.new(cause: e)
end
```

## Why
APM sees nothing when errors are swallowed. Upstream timeout looks like "no results." Debugging requires manual log analysis.
