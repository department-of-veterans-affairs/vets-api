---
id: dont-mix-error-concerns
title: Don't mix error concerns across layers
version: 1
severity: HIGH
category: exception-handling
tags:
- layer-separation
- concern-mixing
- controller-coupling
- domain-exceptions
- response-objects
language: ruby
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

  <retrieval_triggers>
    <trigger>controller catches Faraday or HTTP client exception directly</trigger>
    <trigger>service returns error object instead of raising exception</trigger>
    <trigger>controller coupled to infrastructure library</trigger>
    <trigger>mixed error handling patterns between services</trigger>
    <trigger>response object contains error field instead of raising</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="controller_catches_http_client" confidence="high">
      <signature>rescue\s+Faraday::</signature>
      <description>
        A controller file catching a Faraday exception class directly.
        Controllers should only catch domain exceptions (e.g.,
        `BenefitsClaims::ServiceException`), not infrastructure
        library classes. This couples the controller to the HTTP
        client implementation. Changing HTTP libraries requires
        updating all controllers. Only flag when found in files
        matching `controllers/`.
      </description>
      <example>rescue Faraday::ClientError =&gt; e</example>
      <example>rescue Faraday::TimeoutError =&gt; e</example>
      <example>rescue Faraday::ServerError, Faraday::ClientError =&gt; e</example>
    </pattern>
    <pattern name="response_error_field_check" confidence="medium">
      <signature>\.error\.present\?</signature>
      <description>
        Checking `.error.present?` on a response object returned from
        a service call. This indicates the service returns error
        objects instead of raising exceptions. Callers must use custom
        error checking instead of standard Ruby `rescue` control flow.
        Medium confidence because `.error.present?` can appear in
        legitimate ActiveModel validation checks — verify the object
        is a service response, not a model.
      </description>
      <example>if response.error.present?</example>
      <example>unless response.error.present?</example>
    </pattern>
    <pattern name="http_like_response_with_error" confidence="high">
      <signature>status:\s*200.*error:</signature>
      <description>
        A response object constructor or hash with both a `status:
        200` success code and an `error:` field. This mimics HTTP
        semantics in Ruby-to-Ruby service calls, where exceptions
        should signal failure. A "successful" response containing an
        error field confuses callers and APM — the error is invisible
        to standard exception tracking.
      </description>
      <example>FindProfileResponse.new(status: 200, profile: nil, error: e)</example>
      <example>{ status: 200, error: e }</example>
    </pattern>
    <heuristic>
      A controller that rescues infrastructure exceptions (Faraday,
      HTTParty, Net::HTTP, RestClient) is a strong signal of layer
      violation. Controllers should only rescue domain exceptions
      defined in the module's namespace.
    </heuristic>
    <heuristic>
      A service method that returns a response object with both a
      data field and an error field (instead of raising on failure)
      forces callers to use non-idiomatic conditional checks. Look
      for response objects that can simultaneously contain data and
      error attributes.
    </heuristic>
    <heuristic>
      When some services in a module raise exceptions while others
      return error objects, callers must handle both patterns. This
      inconsistency is a strong signal that error concerns are mixed
      across the codebase.
    </heuristic>
    <false_positive>
      `rescue Faraday::Error` inside a service layer file (not a
      controller) is acceptable and expected. Services SHOULD catch
      infrastructure exceptions and wrap them as domain exceptions.
      Only flag Faraday rescues in controller files.
    </false_positive>
    <false_positive>
      `.error.present?` on ActiveModel objects checking validation
      errors is not a violation. This pattern is only a violation
      when checking error fields on service response objects that
      should have raised exceptions instead.
    </false_positive>
    <false_positive>
      Response objects from external APIs (parsed JSON with status
      and error fields) are not violations when they represent the
      actual upstream response structure. The violation is when Ruby
      services create these structures internally to communicate
      failure between layers.
    </false_positive>
  </detection>

  <rules>
    <rule enforcement="must">
      Service layer must wrap infrastructure exceptions (Faraday,
      HTTP client) into domain-typed exceptions before they reach
      controllers.
    </rule>
    <rule enforcement="must">
      Controllers must catch only domain exceptions, never
      infrastructure library classes.
    </rule>
    <rule enforcement="must">
      Service methods must return data on success and raise on
      failure — not return error objects.
    </rule>
    <rule enforcement="must_not">
      Domain layer must not render responses; controllers must not
      compensate domain logic.
    </rule>
    <rule enforcement="should">
      Controllers should rely on centralized `rescue_from` to render
      standardized error responses.
    </rule>
    <rule enforcement="should">
      All services within a module should use the same error
      handling convention (raise, not return error objects).
    </rule>
    <rule enforcement="verify">
      Controllers only catch domain exceptions (not infrastructure
      classes)
    </rule>
    <rule enforcement="verify">
      Service layer owns infrastructure exception wrapping
    </rule>
    <rule enforcement="verify">
      All service methods use Ruby exception convention (raise on
      failure)
    </rule>
    <rule enforcement="verify">
      Changing HTTP client only requires service layer updates
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

  <default_to_action>
    When you detect a mixed error concerns violation with high
    confidence, compose a PR comment that includes: 1. The
    specific violation (controller catching infrastructure
    exception, or service returning error object) 2. Why it
    matters (coupling, APM blind spots, inconsistent patterns) 3.
    A concrete code suggestion showing the correct layer
    separation 4. The verification checklist items relevant to
    this specific case 5. A link to this play for full context Do
    not simply flag the violation — provide the fix. Show both the
    service layer change and the controller layer change when
    applicable.
  </default_to_action>

  <verify>
    <command description="No Faraday rescue in controller files">
      grep -rOn 'rescue\s+Faraday::' app/controllers/ modules/*/app/controllers/ &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No HTTP-like response with error field in service files">
      grep -rOn 'status:\s*200.*error:' lib/ app/services/ &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

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

    [Play: Don't mix error concerns across layers](plays/dont-mix-error-concerns.md)
  </pr_comment_template>

  <anti_pattern_sources>
    <source name="Chatbot Claim Status Controller" file="app/controllers/v0/chatbot/claim_status_controller.rb:48-50" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/app/controllers/v0/chatbot/claim_status_controller.rb#L48-L50" />
    <source name="MPI Service HTTP-Like Response Objects" file="lib/mpi/service.rb:118-124" url="https://github.com/department-of-veterans-affairs/vets-api/blob/master/lib/mpi/service.rb#L118-L124" />
  </anti_pattern_sources>

</agent_play>
-->

# Don't mix error concerns across layers

Each application layer should own its own error types. Services wrap infrastructure exceptions into domain exceptions; controllers catch only domain exceptions and render responses.

> [!CAUTION]
> Controllers catching infrastructure exceptions (Faraday, HTTP clients) couples every controller to your HTTP library. Change libraries? Update every controller.

## Why It Matters

When your controller catches `Faraday::ClientError` directly, you have coupled it to the Faraday library — switching to HTTParty means updating every controller. If a service returns `{ status: 200, error: e }`, callers see a "successful" response that actually contains an error, forcing non-idiomatic `if response.error` checks everywhere. These buried errors are invisible to APM, lose their stack traces, and break the cause chain, making debugging impossible. When some services raise exceptions and others return error objects, you cannot predict which pattern a given service uses and must handle both.

## Guidance

Keep error concerns in the layer that owns them. Services catch infrastructure exceptions (Faraday, HTTP client errors) and re-raise them as domain-typed exceptions. Controllers catch only domain exceptions and render standardized error responses via `rescue_from`. Service methods return data on success and raise on failure — never return error objects.

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

### Anti-Patterns from vets-api

#### Chatbot Claim Status Controller

##### Anti-Pattern

[app/controllers/v0/chatbot/claim_status_controller.rb:48-50](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/app/controllers/v0/chatbot/claim_status_controller.rb#L48-L50)

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

##### Impact

Without layer separation:

- **Layer violation:** Controller knows about `Faraday` (HTTP client library implementation detail)
- **Service responsibility leak:** Service layer should wrap HTTP exceptions, not controller
- **Testing complexity:** Must mock Faraday in controller tests instead of service interface
- **Code duplication:** Every controller calling this service needs same Faraday handling
- **Brittle coupling:** Changing HTTP client library (Faraday → HTTParty) requires updating all controllers

With layer separation:

- Controller only catches domain exceptions (`BenefitsClaims::ServiceException`)
- Service layer owns HTTP client exception handling
- Easy to mock service interface in controller tests
- Changing HTTP client only affects service layer
- Clear separation: controllers render, services handle business logic

---

#### MPI Service - HTTP-Like Response Objects in Service Layer

##### Anti-Pattern

[lib/mpi/service.rb:118-124](https://github.com/department-of-veterans-affairs/vets-api/blob/master/lib/mpi/service.rb#L118-L124)

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

##### Impact

Without Ruby exception conventions:

- **Inconsistent error handling:** Some services raise exceptions, others return error objects
- **Forces custom patterns:** Every caller must remember to check `response.error.present?`
- **Can't use Ruby control flow:** Standard `rescue` doesn't work with returned error objects
- **HTTP semantics in wrong layer:** `status: 200` is meaningless in Ruby-to-Ruby service calls
- **APM blind spot:** Errors buried in "successful" response objects don't propagate stack traces naturally
- **Testing complexity:** Must test both exception paths AND error object paths

With Ruby exception conventions:

- **Idiomatic Ruby:** Exceptions for exceptional conditions, return values for success
- **Standard control flow:** Use `rescue` to handle errors, no custom checking needed
- **Clear success/failure:** Method returns profile on success, raises on failure
- **APM-friendly:** Exceptions propagate with full stack traces and context
- **Consistent patterns:** All services use same error handling approach

## References

- [Rails Controller Concerns](https://guides.rubyonrails.org/action_controller_overview.html)
