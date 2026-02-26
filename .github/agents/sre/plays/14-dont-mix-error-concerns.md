---
id: dont-mix-error-concerns
title: Don't mix error concerns across layers
severity: HIGH
---

<!--
<agent_play>

  <context>
    When a controller catches Faraday::ClientError directly, it becomes
    coupled to the Faraday library, so switching to HTTParty would
    require updating every controller. A service that returns `{ status:
    200, error: e }` looks successful but contains an error, forcing
    callers into non-idiomatic `if response.error` checks. Errors buried
    in response objects are invisible to APM, lose their stack traces,
    and break the cause chain, making debugging impossible. When some
    services raise exceptions and others return error objects, callers
    cannot know which pattern to expect and must handle both.
  </context>

  <applies_to>
    <glob>app/controllers/**/*.rb</glob>
    <glob>modules/*/app/controllers/**/*.rb</glob>
    <glob>lib/**/*.rb</glob>
    <glob>app/services/**/*.rb</glob>
    <glob>modules/*/app/services/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="preserve-cause-chains" relationship="complementary" />
    <play id="standardized-error-responses" relationship="complementary" />
  </related_plays>

  <rules>
    <rule enforcement="must">
      Service layer must wrap infrastructure exceptions (Faraday,
      HTTP client) into domain-typed exceptions before they reach
      controllers.
    </rule>
    <rule enforcement="must">
      Controllers must catch only domain exceptions, never
      infrastructure library classes directly.
    </rule>
    <rule enforcement="must">
      Service methods must return data on success and raise on
      failure — not return error objects.
    </rule>
    <rule enforcement="must">
      Keep rendering in controllers and domain logic in services —
      neither layer should cross into the other's responsibility.
    </rule>
    <rule enforcement="should">
      Rely on centralized `rescue_from` in ExceptionHandling to
      render standardized error responses.
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Determine which layer the violation is in — controller catching infrastructure exceptions, or service returning error objects instead of raising.</step>
    <step>Read the service layer to identify what exception types it can raise and whether typed domain exceptions already exist in the module's namespace.</step>
    <step>Check if the controller's rescue block does anything beyond what centralized `rescue_from` would handle (custom response rendering, business logic).</step>
    <step>For response object violations, identify all callers of the service method to understand the impact of changing from error objects to exceptions.</step>
    <step>Verify whether domain exception classes need to be created or already exist in the module's `exceptions/` or `errors/` directory.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>controller catches infrastructure exceptions in code handling
PII, PHI, or financial data (claims, health records, benefits)</critical>
    <critical>service returns error objects that hide exceptions from APM in
user-facing request paths</critical>
    <high>controller catches Faraday or HTTP client exceptions in any
service call</high>
    <high>service returns response objects with error fields instead of
raising exceptions</high>
    <medium>inconsistent error handling patterns between services in the
same module</medium>
  </severity_assessment>

  <pr_comment_template>
    **Don't mix error concerns across layers** | `HIGH`

    `{{file_path}}:{{line_number}}` — {{one_line_violation_description}}

    **Why this matters:** {{why_it_matters_summary}}

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    - [ ] Controllers only catch domain exceptions (not infrastructure classes)
    - [ ] Service layer wraps infrastructure exceptions with `cause: e`
    - [ ] Service methods raise on failure (no error objects returned)
    - [ ] Changing HTTP client only requires service layer updates

    [Play: Don't mix error concerns across layers](14-dont-mix-error-concerns.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- Wrap infrastructure exceptions (Faraday) into domain-typed exceptions in the service layer:
  ```ruby
  # Service layer
  rescue Faraday::ClientError => e
    raise BenefitsClaims::ServiceException.new(e.response, cause: e)
  ```
- Catch only domain exceptions in controllers:
  ```ruby
  # Controller
  rescue BenefitsClaims::ServiceException => e
    render_api_exception(e)
  ```
- Return data on success, raise on failure in service methods:
  ```ruby
  def get_claims
    response = faraday_client.get('/claims')
    response.body  # return data on success
  rescue Faraday::ClientError => e
    raise BenefitsClaims::ServiceException.new(cause: e)  # raise on failure
  end
  ```

### Don't

- Catch Faraday or HTTP client exceptions in controllers:
  ```ruby
  # Controller — violation: knows about Faraday
  rescue Faraday::ClientError => e
    service_exception_handler(e)
  ```
- Return error objects from service methods instead of raising:
  ```ruby
  # Service — violation: returns error object
  FindProfileResponse.new(status: 200, profile: nil, error: e)
  ```
- Let the domain layer render responses:
  ```ruby
  # Service — violation: rendering belongs in the controller
  render json: { error: e.message }, status: 500
  ```

## Anti-Patterns

#### Chatbot Claim Status Controller

##### Anti-Pattern

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

##### Golden Pattern

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

#### MPI Service - HTTP-Like Response Objects in Service Layer

##### Anti-Pattern

```ruby
def find_profile_by_identifier(identifier:, identifier_type:, search_type:)
  with_monitoring do
    raw_response = perform(:post, '', message.perform, soapaction: Constants::FIND_PROFILE)
    parse_response(raw_response)
  end
rescue *CONNECTION_ERRORS => e
  # Returns "successful" response object with error field (HTTP-like semantics in Ruby)
  MPI::Services::FindProfileResponseCreator.new(
    type: Constants::FIND_PROFILE_BY_IDENTIFIER_TYPE,
    error: e
  ).perform
end

# Response object structure (mimics HTTP):
FindProfileResponse.new(
  status: 200,      # "Success" status code
  profile: nil,     # But no profile data
  error: e          # Contains the actual exception
)

# Callers must use custom error checking instead of standard exception handling
response = mpi_service.find_profile_by_identifier(...)
if response.error.present?
  # Custom error handling logic
  handle_mpi_error(response.error)
else
  process_profile(response.profile)
end
```

##### Golden Pattern

```ruby
# Service layer: Let exceptions propagate naturally
def find_profile_by_identifier(identifier:, identifier_type:, search_type:)
  with_monitoring do
    raw_response = perform(:post, '', message.perform, soapaction: Constants::FIND_PROFILE)
    parse_response(raw_response)
  end
  # CONNECTION_ERRORS propagate as exceptions (Ruby convention)
rescue Faraday::ConnectionFailed => e
  # Re-raise as domain exception with cause
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
