# Play: Classify Errors Honestly (4xx vs 5xx)

## Detect
Patterns to flag in code reviews:
- `rescue => e; raise UnprocessableEntity` - catches our bugs, returns 422 (blames client)
- Broad rescue returning 422 for all failures - may hide 500s or 504s
- Database/upstream errors returning 422 - infrastructure issues blamed on client
- Missing "who fixes this?" consideration in error handling

## Fix
```ruby
# Bad: All failures become 422 (client error)
def initialize(user, claim_data)
  @first_name = user.first_name
rescue => e
  raise Common::Exceptions::UnprocessableEntity.new(detail: 'Could not initialize')
end

# Good: Status code matches who needs to fix it
def initialize(user, claim_data)
  @first_name = user.first_name
  validate_required_fields!
rescue ArgumentError, ActiveModel::ValidationError => e
  # Client sent bad data - they fix it (422)
  raise Common::Exceptions::UnprocessableEntity.new(detail: e.message)
# NoMethodError, BGS::ServiceError will raise as 500/5xx - we fix it
# Don't rescue them here - let controller exception handling classify them
end
```

**Decision rule: "Who fixes this?"**
- Client's bad input → 4xx
- Our code bug → 500
- Upstream unavailable → 502/503/504

## Why
NoMethodError returning 422 means our bugs count as client errors in metrics. Team investigates "validation failures" that are actually our code bugs.
