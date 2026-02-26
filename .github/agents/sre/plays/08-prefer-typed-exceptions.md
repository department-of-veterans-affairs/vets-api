---
id: prefer-typed-exceptions-v2
title: Prefer Typed Exceptions with Domain-Specific Subclasses
severity: CRITICAL
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

    [Play: Prefer Typed Exceptions](08-prefer-typed-exceptions.md)
  </pr_comment_template>

</agent_play>
-->

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

```ruby
def authenticate
  raise 'A user_key is required for session creation' unless user_key
  # Creates RuntimeError -> falls through to 500 handler
  # ...
end
```

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
