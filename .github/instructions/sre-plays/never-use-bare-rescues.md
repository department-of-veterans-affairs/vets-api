# Play: Never Use Bare Rescues

## Detect
Patterns to flag in code reviews:
- `rescue => e` without exception class - catches all `StandardError` (including `NoMethodError` from typos)
- `rescue` without any class - same as above
- `rescue Exception` - catches `StandardError` AND `SystemExit`/`Interrupt` (Ctrl+C), almost never correct
- Any broad rescue returning nil/false - hides code bugs as "no results"

## Fix
```ruby
# Bad: Catches typos, timeouts, DB errors - all return nil
def veteran_va_file_number(user)
  response = BGS::People::Request.new.find_person_by_participant_id(user:)
  response.file_number
rescue => e
  Rails.logger.warn('Unable to find file number')
  nil
end

# Good: Catches only expected errors, lets bugs raise to APM
def veteran_va_file_number(user)
  response = BGS::People::Request.new.find_person_by_participant_id(user:)
  response.file_number
rescue BGS::ServiceError, Faraday::TimeoutError
  raise Common::Exceptions::GatewayTimeout  # 504
rescue Faraday::ConnectionFailed
  raise Common::Exceptions::ServiceUnavailable.new(detail: 'BGS unavailable')  # 503
end
# NoMethodError from typos will raise to APM, not be swallowed
```

## Why
Bare rescue catches `NoMethodError` from typos. Code bugs ship to production. APM never sees the error. Typo looks like "veteran has no file number."
