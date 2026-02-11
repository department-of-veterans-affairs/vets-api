# Play 14: Don't Mix Error Concerns Across Layers

## Context
When a controller catches Faraday::ClientError directly, it becomes coupled to the Faraday library, so switching to HTTParty would require updating every controller. A service that returns `{ status: 200, error: e }` looks successful but contains an error, forcing callers into non-idiomatic `if response.error` checks. Errors buried in response objects are invisible to APM, lose their stack traces, and break the cause chain, making debugging impossible.

## Applies To
- `app/controllers/**/*.rb`
- `modules/*/app/controllers/**/*.rb`
- `lib/**/*.rb`
- `app/services/**/*.rb`
- `modules/*/app/services/**/*.rb`

## Investigation Steps
1. Determine which layer the violation is in -- controller catching infrastructure exceptions, or service returning error objects instead of raising.
2. Read the service layer to identify what exception types it can raise and whether typed domain exceptions already exist in the module's namespace.
3. Check if the controller's rescue block does anything beyond what centralized `rescue_from` would handle (custom response rendering, business logic).
4. For response object violations, identify all callers of the service method to understand the impact of changing from error objects to exceptions.
5. Verify whether domain exception classes need to be created or already exist in the module's `exceptions/` or `errors/` directory.

## Severity Assessment
- **CRITICAL:** Controller catches infrastructure exceptions in code handling PII, PHI, or financial data (claims, health records, benefits)
- **CRITICAL:** Service returns error objects that hide exceptions from APM in user-facing request paths
- **HIGH:** Controller catches Faraday or HTTP client exceptions in any service call
- **HIGH:** Service returns response objects with error fields instead of raising exceptions
- **MEDIUM:** Inconsistent error handling patterns between services in the same module

## Golden Patterns

### Do
Wrap infrastructure exceptions into domain-typed exceptions in the service layer:
```ruby
# Service layer
rescue Faraday::ClientError => e
  raise BenefitsClaims::ServiceException.new(e.response, cause: e)
```

Catch only domain exceptions in controllers:
```ruby
# Controller
rescue BenefitsClaims::ServiceException => e
  render_api_exception(e)
```

Return data on success, raise on failure in service methods:
```ruby
def get_claims
  response = faraday_client.get('/claims')
  response.body  # return data on success
rescue Faraday::ClientError => e
  raise BenefitsClaims::ServiceException.new(cause: e)  # raise on failure
end
```

### Don't
Never catch Faraday or HTTP client exceptions in controllers:
```ruby
# BAD: Controller knows about Faraday
rescue Faraday::ClientError => e
  service_exception_handler(e)
```

Never return error objects from service methods instead of raising:
```ruby
# BAD: Returns error object instead of raising
FindProfileResponse.new(status: 200, profile: nil, error: e)
```

Never let the domain layer render responses:
```ruby
# BAD: Rendering belongs in the controller
render json: { error: e.message }, status: 500
```

## Anti-Patterns

### Chatbot Claim Status Controller
**Anti-pattern:**
```ruby
def poll_claims_from_lighthouse
  begin
    raw_claim_list = lighthouse_service.get_claims['data']
    claims = order_claims_lighthouse(raw_claim_list)
  rescue Common::Exceptions::ResourceNotFound => e
    log_no_claims_found(e)
    claims = []
  rescue Faraday::ClientError => e  # Controller catching HTTP client exception!
    service_exception_handler(e)
    raise BenefitsClaims::ServiceException.new(e.response), 'Could not retrieve claims'
  end
end
```
**Problem:** Controller knows about Faraday (HTTP client library implementation detail). Service layer should wrap HTTP exceptions, not controller. Testing complexity increases -- must mock Faraday in controller tests. Changing HTTP client library requires updating all controllers.

**Corrected:**
```ruby
# Service layer (lighthouse_service.rb)
def get_claims
  response = faraday_client.get('/claims')
  response.body
rescue Faraday::ClientError => e
  raise BenefitsClaims::ServiceException.new(e.response, cause: e)
rescue Faraday::TimeoutError => e
  raise Common::Exceptions::GatewayTimeout.new(cause: e)
end

# Controller (clean, no HTTP client knowledge)
def poll_claims_from_lighthouse
  raw_claim_list = lighthouse_service.get_claims['data']
  order_claims_lighthouse(raw_claim_list)
rescue BenefitsClaims::ServiceException => e
  render_api_exception(e)
end
```

### MPI Service HTTP-Like Response Objects
**Anti-pattern:**
```ruby
def find_profile_by_identifier(identifier:, identifier_type:, search_type:)
  with_monitoring do
    raw_response = perform(:post, '', message.perform, soapaction: Constants::FIND_PROFILE)
    parse_response(raw_response)
  end
rescue *CONNECTION_ERRORS => e
  # Returns "successful" response object with error field
  MPI::Services::FindProfileResponseCreator.new(
    type: Constants::FIND_PROFILE_BY_IDENTIFIER_TYPE,
    error: e
  ).perform
end

# Callers must use custom error checking
response = mpi_service.find_profile_by_identifier(...)
if response.error.present?
  handle_mpi_error(response.error)
else
  process_profile(response.profile)
end
```
**Problem:** Inconsistent error handling -- some services raise exceptions, others return error objects. Forces custom patterns where every caller must check `response.error.present?`. Standard `rescue` does not work with returned error objects. `status: 200` is meaningless in Ruby-to-Ruby service calls. Errors buried in "successful" response objects do not propagate stack traces to APM.

**Corrected:**
```ruby
# Service layer: Let exceptions propagate naturally
def find_profile_by_identifier(identifier:, identifier_type:, search_type:)
  with_monitoring do
    raw_response = perform(:post, '', message.perform, soapaction: Constants::FIND_PROFILE)
    parse_response(raw_response)
  end
rescue Faraday::ConnectionFailed => e
  raise MPI::Errors::ServiceUnavailable.new(
    'MPI service connection failed',
    cause: e
  )
end

# Callers use standard Ruby exception handling
begin
  profile = mpi_service.find_profile_by_identifier(...)
  process_profile(profile)
rescue MPI::Errors::ServiceUnavailable => e
  handle_connection_error(e)
rescue MPI::Errors::ProfileNotFound => e
  handle_not_found(e)
end
```

## Finding Template
**Don't mix error concerns across layers** | `HIGH`

`{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

**Why this matters:** {{why_it_matters_summary}}

**Suggested fix:**
```ruby
{{suggested_code}}
```

- [ ] Controllers only catch domain exceptions (not infrastructure classes)
- [ ] Service layer wraps infrastructure exceptions with `cause: e`
- [ ] Service methods raise on failure (no error objects returned)
- [ ] Changing HTTP client only requires service layer updates

[Play: Don't mix error concerns across layers](plays/dont-mix-error-concerns.md)

## Verify Commands
```bash
# No Faraday rescue in controller files
grep -rOn 'rescue\s+Faraday::' app/controllers/ modules/*/app/controllers/ && exit 1 || exit 0

# No HTTP-like response with error field in service files
grep -rOn 'status:\s*200.*error:' lib/ app/services/ && exit 1 || exit 0

# Run specs for changed file
bundle exec rspec {{spec_path}}

# RuboCop passes for changed file
bundle exec rubocop {{file_path}}
```

## Related Plays
- Play: Preserve Cause Chains (complementary)
- Play: Standardized Error Responses (complementary)
