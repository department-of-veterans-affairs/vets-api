---
id: prefer-typed-exceptions-v2
title: Prefer Typed Exceptions with Domain-Specific Subclasses
version: 1
severity: CRITICAL
category: exception-handling
tags:
- typed-exceptions
- runtime-error
- domain-hierarchy
- case-study
- exception-mapping
language: ruby
---

<!--
<agent_play>

  <context>
    Untyped string raises become generic RuntimeError instances that
    fall through to 500 error handlers, making client errors
    indistinguishable from server failures. This misclassification
    triggers unnecessary alerts, inflates error metrics, and obscures
    root causes during incident response. Typed exceptions that inherit
    from semantic base classes automatically route errors to the
    appropriate HTTP status codes. With proper typing, monitoring
    systems categorize failures accurately and teams receive alerts only
    for genuine server issues.
  </context>

  <applies_to>
    <glob>app/controllers/**/*.rb</glob>
    <glob>app/sidekiq/**/*.rb</glob>
    <glob>lib/**/*.rb</glob>
    <glob>modules/*/app/controllers/**/*.rb</glob>
    <glob>modules/*/lib/**/*.rb</glob>
    <glob>app/services/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="classify-errors" relationship="complementary" />
    <play id="preserve-cause-chains" relationship="complementary" />
  </related_plays>

  <retrieval_triggers>
    <trigger>RuntimeError from untyped raise returns 500 for client error</trigger>
    <trigger>production incident from raise string instead of typed exception</trigger>
    <trigger>165 instances of untyped raise across codebase</trigger>
    <trigger>domain-specific exception hierarchy design</trigger>
    <trigger>exception to HTTP status code mapping</trigger>
    <trigger>MHV session authentication failure case study</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="untyped_string_raise" confidence="high">
      <signature>raise\s+['"][^'"]+['"]</signature>
      <description>
        Untyped `raise 'message'` or `raise "message"`. In Ruby,
        raising a string creates a generic RuntimeError that falls
        through to the 500 handler in vets-api's ExceptionHandling
        concern. This pattern catches all string raises regardless of
        message content.
      </description>
      <example>raise 'A user_key is required for session creation'</example>
      <example>raise "Missing/malformed form_number in params"</example>
      <example>raise 'ContactInformationV2 - Missing User VAProfile_ID'</example>
    </pattern>
    <pattern name="untyped_raise_required" confidence="high">
      <signature>raise\s+['"].*required</signature>
      <description>
        Untyped raise with a message containing "required." These
        typically indicate missing authentication tokens, required
        parameters, or precondition failures that should be 4xx client
        errors but become 500 Internal Server Errors as RuntimeError
        instances.
      </description>
      <example>raise 'A user_key is required for session creation'</example>
      <example>raise "API key is required"</example>
    </pattern>
    <pattern name="untyped_raise_missing" confidence="high">
      <signature>raise\s+['"].*missing</signature>
      <description>
        Untyped raise with a message containing "missing." These
        indicate missing data, parameters, or identifiers that
        represent client errors or incomplete data setup, not server
        failures. The RuntimeError will be treated as a 500.
      </description>
      <example>raise 'Missing/malformed form_number in params'</example>
      <example>raise 'ContactInformationV2 - Missing User VAProfile_ID'</example>
    </pattern>
    <heuristic>
      A method that validates preconditions (authentication tokens,
      required IDs, parameter presence) using `raise 'string'`
      instead of typed exceptions is a high-priority violation.
      These are client errors masquerading as server failures.
    </heuristic>
    <heuristic>
      Code in HTTP request paths (controllers, service objects
      called from controllers) where `raise 'string'` will bubble up
      through the ExceptionHandling concern and become a 500
      Internal Server Error. Check the call stack to determine if
      the raise is in a request path.
    </heuristic>
    <heuristic>
      A service or client class with multiple `raise 'string'`
      statements suggests the module lacks a domain-specific
      exception hierarchy. Look for opportunities to create a base
      exception class for the domain and semantic subclasses for
      specific failure modes.
    </heuristic>
    <false_positive>
      `raise 'string'` in rake tasks or CLI scripts that are not in
      HTTP request paths. These raises produce RuntimeError but do
      not affect HTTP status codes or API responses. Lower priority
      for remediation.
    </false_positive>
    <false_positive>
      `raise 'string'` in test/spec files where the raise is being
      tested or is part of test setup. Test code may intentionally
      raise strings to verify error handling behavior.
    </false_positive>
    <false_positive>
      `raise SomeTypedException, 'message'` where a string is passed
      as the message argument to a typed exception constructor. This
      is correct usage — the string is the message, not the
      exception type.
    </false_positive>
  </detection>

  <rules>
    <rule enforcement="must">
      Use typed exception classes instead of `raise 'string'` in all
      HTTP request paths. String raises create RuntimeError that
      defaults to 500.
    </rule>
    <rule enforcement="must">
      Choose exception classes that map to the correct HTTP status
      code for the failure mode (e.g., ParameterMissing for 400,
      UnprocessableEntity for 422).
    </rule>
    <rule enforcement="must_not">
      Never use `raise 'message'` for client errors (missing params,
      validation failures, auth issues) — these become
      indistinguishable 500s.
    </rule>
    <rule enforcement="should">
      Create domain-specific exception hierarchies when a module has
      multiple failure modes that need distinct handling.
    </rule>
    <rule enforcement="verify">
      No untyped string raises remain in HTTP request paths
    </rule>
    <rule enforcement="verify">
      Client errors return correct 4xx status (not 500)
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full method containing the `raise 'string'` to understand the precondition being enforced — is it authentication, parameter validation, data integrity, or a service contract?</step>
    <step>Determine the correct HTTP status code for the failure mode:</step>
    <step>Check if typed exceptions already exist in the module's namespace or in `Common::Exceptions` for the specific failure mode.</step>
    <step>Identify whether this raise is in an HTTP request path (controller, service called from controller) or in a background job / rake task, as the impact differs significantly.</step>
    <step>Look for other `raise 'string'` patterns in the same file or module — if there are several, recommend creating a domain-specific exception hierarchy. Do not suggest a fix without understanding what semantic error type the string raise represents. The correct typed exception depends on the failure mode.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>untyped raise in controller or service handling
authentication, health records, or benefits claims</critical>
    <critical>untyped raise that caused or could cause a production incident
(misclassified 500 for client error)</critical>
    <high>untyped raise in any HTTP request path (controller action,
service called from controller)</high>
    <high>untyped raise in background job where RuntimeError triggers
inappropriate retries</high>
    <medium>untyped raise in rake task, utility, or code not in HTTP
request path</medium>
  </severity_assessment>

  <default_to_action>
    When you detect an untyped `raise 'string'`, determine the
    failure mode and provide a fix using the correct typed exception
    from Common::Exceptions. Include structured metadata.
  </default_to_action>

  <verify>
    <command description="No untyped string raises remain in changed file">
      grep -On "raise\s+['\"][^'\"]+['\"]" {{file_path}} | grep -v "raise [A-Z]" &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for the changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

  <pr_comment_template>
    **Prefer Typed Exceptions with Domain-Specific Subclasses** | `CRITICAL`

    `{{file_path}}:{{line_number}}` — `raise '{{message}}'` creates a generic
    RuntimeError that falls through to the 500 handler. This {{failure_mode}}
    should return {{correct_status_code}}, not 500 Internal Server Error.

    **Why this matters:** RuntimeError bypasses all specific exception handlers
    and defaults to 500. Client errors become indistinguishable from server
    failures. Monitoring triggers false alerts. Error metrics are inflated.

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    - [ ] Uses typed exception class (not RuntimeError)
    - [ ] Maps to correct HTTP status code ({{correct_status_code}})
    - [ ] Includes structured metadata (detail, source)
    - [ ] Framework exception handler recognizes the new type

    [Play: Prefer Typed Exceptions](plays/prefer-typed-exceptions.md)
  </pr_comment_template>

  <anti_pattern_sources>
    <source name="MHV Session Authentication Failure" file="inline-example" />
    <source name="IVC CHAMPVA Upload Validation" file="inline-example" />
    <source name="VAProfile Contact Information" file="inline-example" />
  </anti_pattern_sources>

</agent_play>
-->

# Prefer Typed Exceptions with Domain-Specific Subclasses

Every `raise "message"` creates a generic `RuntimeError` that falls through to the 500 handler. Use typed exception classes that map to the correct HTTP status code.

> [!CAUTION]
> Generic RuntimeError bypasses all specific exception handlers and defaults to 500 Internal Server Error, even for client-side issues like missing parameters or invalid authentication tokens.

## Why It Matters

When you use `raise 'A user_key is required'`, Ruby creates a `RuntimeError`. The framework's exception handler checks the type against known patterns — `ParameterMissing` maps to 400, `UnprocessableEntity` to 422 — but `RuntimeError` matches nothing, so it defaults to 500. A missing authentication token, an invalid parameter, a failed validation — all become indistinguishable 500 errors. Monitoring triggers false alerts, error metrics are inflated, and on-call investigates "server failures" that are actually client issues.

## Guidance

Replace `raise 'string'` with typed exceptions from `Common::Exceptions` or your module's exception hierarchy. Choose the class that maps to the correct HTTP status code for the failure mode: `ParameterMissing` for 400, `Unauthorized` for 401, `UnprocessableEntity` for 422. When a module has multiple failure modes, create domain-specific subclasses that inherit from semantic base types.

### Do

- `raise Common::Exceptions::ParameterMissing.new('form_number')` — returns 400
- `raise Common::Exceptions::UnprocessableEntity.new(detail: 'Missing user_key')` — returns 422
- Create `Paws::DuplicateApplicationError < PawsError` for domain-specific failures

### Don't

- `raise 'A user_key is required'` — creates RuntimeError, returns 500
- `raise "Missing/malformed form_number"` — client error masquerading as server failure
- `raise 'ContactInformationV2 - Missing User VAProfile_ID'` — validation error returned as 500

## Anti-Patterns

### MHV Session Authentication Failure

> Production incident: September 11, 2025, 4:00-5:15 PM Eastern. Veterans received 500 errors accessing health records. Root cause: missing `user_key` raised as RuntimeError.

```ruby
def authenticate
  raise 'A user_key is required for session creation' unless user_key
  # Creates RuntimeError -> falls through to 500 handler
  # ...
end
```

**Problem:** A missing `user_key` is a data issue (422), not a server failure (500). The RuntimeError fell through the exception handler's type checks and defaulted to 500. Monitoring showed "server errors" while the actual problem was missing authentication data.

**Corrected:**

```ruby
def authenticate
  unless user_key
    raise Common::Exceptions::UnprocessableEntity.new(
      detail: 'Cannot establish MHV session: missing required user_key',
      source: 'MHVLockedSessionClient#authenticate'
    )
  end
  # Returns 422 — framework recognizes the type automatically
end
```

### IVC CHAMPVA Upload Validation

```ruby
def get_form_id
  form_number = params[:form_number]
  raise 'Missing/malformed form_number in params' unless form_number
  FORM_NUMBER_MAP[form_number]
end
```

**Problem:** A missing required parameter should return 400 Bad Request, not 500. The client needs to know which parameter is missing.

**Corrected:**

```ruby
def get_form_id
  form_number = params[:form_number]
  unless form_number
    raise Common::Exceptions::ParameterMissing.new(
      'form_number',
      detail: 'The form_number parameter is required for form uploads'
    )
  end
  # Returns 400 Bad Request with clear error message
  FORM_NUMBER_MAP[form_number]
end
```

### VAProfile Contact Information

```ruby
def verify_vet360_id!
  raise 'ContactInformationV2 - Missing User VAProfile_ID' if @user&.vet360_id.blank?
end
```

**Problem:** A missing VAProfile ID is incomplete data setup (422), not a server failure (500). Metrics show this as a server error while the actual problem is a data prerequisite.

**Corrected:**

```ruby
def verify_vet360_id!
  if @user&.vet360_id.blank?
    raise Common::Exceptions::UnprocessableEntity.new(
      detail: 'User must have a VAProfile ID to update contact information',
      source: 'VAProfile::ContactInformation::V2::Service'
    )
  end
  # Returns 422 — data setup incomplete, not server failure
end
```

## Reference

### Domain-Specific Exception Hierarchy

When a module has multiple failure modes, create a hierarchy instead of using string raises:

```ruby
module Paws
  class PawsError < StandardError
    attr_reader :claim_id, :user_uuid

    def initialize(message, claim_id: nil, user_uuid: nil)
      super(message)
      @claim_id = claim_id
      @user_uuid = user_uuid
    end
  end

  class DuplicateApplicationError < PawsError; end
  class IneligibleApplicantError < PawsError; end
end
```

Each exception type maps to a specific HTTP status and error response:

```ruby
rescue Paws::DuplicateApplicationError => e
  render json: { errors: [{ status: '409', code: 'duplicate_application',
    detail: e.message }] }, status: :conflict
rescue Paws::IneligibleApplicantError => e
  render json: { errors: [{ status: '422', code: 'ineligible_applicant',
    detail: e.message }] }, status: :unprocessable_entity
end
```

### Framework Exception-to-Status Mapping

```ruby
ActionDispatch::ExceptionWrapper.rescue_responses.merge!(
  'Common::Exceptions::ParameterMissing'     => :bad_request,          # 400
  'Common::Exceptions::UnauthorizedError'    => :unauthorized,         # 401
  'Common::Exceptions::ForbiddenError'       => :forbidden,            # 403
  'Common::Exceptions::RecordNotFound'       => :not_found,            # 404
  'Common::Exceptions::UnprocessableEntity'  => :unprocessable_entity, # 422
  'Common::Exceptions::ServiceUnavailable'   => :service_unavailable   # 503
)
```

With untyped raises, everything falls through to the default (500). With typed exceptions, the framework routes automatically.

## References

- [Ruby Exception Hierarchy](https://ruby-doc.org/core/Exception.html)
- [Common::Exceptions namespace](https://github.com/department-of-veterans-affairs/vets-api/tree/master/lib/common/exceptions)
- Related: [Match Status Codes to the Source](05-classify-errors-honestly.md)
- Related: [Preserve Cause Chains](02-preserve-cause-chains.md)
