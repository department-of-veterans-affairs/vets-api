# Play 05: Classify Errors Honestly (4xx vs 5xx)

## Context
When a NoMethodError is caught by a bare rescue and returns 422, metrics incorrectly count a server bug as a client error, and the team investigates a "validation failure" that does not exist. A database outage that returns 422 tells the client their data is invalid, when in reality the infrastructure has failed and the client can do nothing to fix it. A BGS timeout that returns 422 causes the client to retry with the same data, which will never help because the upstream service is timing out. Dashboards show rising client errors, but the actual problems are our bugs, our database, and upstream timeouts, so the wrong team investigates with the wrong fix.

## Applies To
- `app/controllers/**/*.rb`
- `modules/*/app/controllers/**/*.rb`
- `lib/**/*.rb`
- `app/sidekiq/**/*.rb`

## Investigation Steps
1. Read the full method containing the rescue block to understand what code is protected and what exception types it can raise.
2. Identify which exceptions represent client data problems (should be 422) vs our code bugs (should be 500) vs upstream failures (should be 502/503/504).
3. Determine whether typed validation exceptions already exist in the module's namespace (check for `ValidationError` or similar classes).
4. Check if the method calls external services (BGS, MPI, Faraday) whose failures should NOT be classified as client errors.
5. Verify that `Common::Exceptions::UnprocessableEntity`, `InternalServerError`, and gateway exceptions are available in the module's namespace. Do not suggest returning 422 for any exception type that represents a server-side or upstream failure. The "who fixes it" question determines the status family.

## Severity Assessment
- **CRITICAL**: Bare rescue returns 422 in code that processes veteran claims, benefits, or health data
- **CRITICAL**: All exception types mapped to client error (4xx) causing complete misattribution in metrics
- **HIGH**: Broad rescue returns 422 in service layer calling external APIs (BGS, MPI, Lighthouse)
- **MEDIUM**: Rescue returns 422 but catches a reasonably narrow set of exceptions that could be narrowed further

## Golden Patterns

### Do
Catch only specific validation exceptions before returning 422:
```ruby
rescue ValidationError, ArgumentError => e
  raise Common::Exceptions::UnprocessableEntity.new(
    detail: e.message,
    cause: e
  )
# Client can fix their data
```

Let `NoMethodError` propagate -- our bug, should be 500. Let `Faraday::TimeoutError` propagate -- upstream issue, should be 504.

### Don't
Never use bare rescue then raise 422 -- catches everything, blames client for our bugs:
```ruby
# BAD
rescue => e
  raise Common::Exceptions::UnprocessableEntity.new(detail: 'Could not process')
end
```

Never rebrand 5xx as 4xx to quiet dashboards -- hides real problems. Never rebrand 4xx as 5xx for attention -- creates false alarms.

## Anti-Patterns

### Dependents Benefits UserData
**Anti-pattern:**
```ruby
def initialize(user, claim_data)
  @first_name = user.first_name.presence || claim_data.dig('veteran_information', 'full_name', 'first')
  # ... more assignments ...
rescue => e  # Bare rescue catches ALL errors
  monitor.track_user_data_error('DependentsBenefits::UserData#initialize error',
                                'user_hash.failure', error: e)
  raise Common::Exceptions::UnprocessableEntity.new(detail: 'Could not initialize user data')
  # Returns 422 (client error) for ALL failures -- even our bugs!
end
```
**Problem:** Bare `rescue => e` catches `NoMethodError` from typos, database errors, and upstream timeouts. Returns 422 for all failure modes -- metrics count our bugs as client validation errors, and the wrong team investigates.

**Corrected:**
```ruby
def initialize(user, claim_data)
  @first_name = user.first_name.presence || claim_data.dig('veteran_information', 'full_name', 'first')
  # ... more assignments ...
  validate_required_fields!
rescue ArgumentError, ValidationError => e
  monitor.track_user_data_error('Validation failed', 'user_hash.validation_error', error: e)
  raise Common::Exceptions::UnprocessableEntity.new(
    code: 'INVALID_USER_DATA',
    detail: e.message,
    cause: e
  )
# Don't catch NoMethodError, BGS::ServiceError, etc. -- let them raise as 500s
end
```

## Finding Template
**Classify errors honestly (4xx vs 5xx)** | `CRITICAL`

`{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

**Why this matters:** Returning 422 (client error) for server-side failures
means metrics blame clients for our bugs. Dashboards show "validation errors"
when the actual problems are our code bugs, database failures, or upstream
timeouts. The team that should fix the problem never gets paged.

**Ask: "Who fixes this?"**
- Client's bad input -> 422 (client error)
- Our code bug -> 500 (server error)
- Upstream timeout -> 504 (gateway timeout)

**Suggested fix:**
```ruby
{{suggested_code}}
```

**Verify:**
- [ ] Rescue catches only validation exceptions (not bare rescue)
- [ ] NoMethodError propagates as 500 (not 422)
- [ ] Upstream timeouts propagate as 504 (not 422)
- [ ] Cause chain preserved with `cause: e`
- [ ] Metrics correctly split client errors vs server errors

[Play: Match Status Codes to the Source](plays/match-status-codes-to-the-source.md)

## Verify Commands
- `grep -On 'rescue\s*=>\s*e.*\n.*UnprocessableEntity' {{file_path}}` -- No bare rescue returning UnprocessableEntity
- `grep -On 'rescue\s+(StandardError|RuntimeError|Exception).*\n.*UnprocessableEntity' {{file_path}}` -- No broad rescue returning 422
- `bundle exec rspec {{spec_path}}` -- Run specs for changed file
- `bundle exec rubocop {{file_path}}` -- RuboCop passes for changed file

## Related Plays
- handle-401-token-ownership (complementary)
- handle-403-permission (complementary)
- map-upstream-network-errors (complementary)
