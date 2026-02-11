---
id: standardized-error-responses
title: 'Standardized Error Responses: Use Central Renderer with Consistent Format'
version: 1
severity: CRITICAL
category: api-design
tags:
- error-format
- json-api
- exception-handling
- manual-render
- central-renderer
language: ruby
---

<!--
<agent_play>

  <context>
    With 119 endpoints returning 6 different error formats, clients need
    6 separate parsers and cannot use standard error-handling libraries.
    Over 15 manual renders bypass ExceptionHandling and return 200 OK
    with an error body, so CDN caches it and monitoring sees success
    when there is a failure. Without error codes, clients must parse
    English strings like `if (msg.includes('Invalid'))`, which breaks
    when translations change the message text. A manual render returns
    `{ error: 'msg' }` while the standard format is `{ errors: [...] }`,
    creating inconsistency that breaks clients expecting one format.
  </context>

  <applies_to>
    <glob>app/controllers/**/*.rb</glob>
    <glob>modules/*/app/controllers/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="classify-errors" relationship="prerequisite" />
    <play id="stable-unique-error-codes" relationship="complementary" />
    <play id="never-return-2xx" relationship="complementary" />
  </related_plays>

  <retrieval_triggers>
    <trigger>manual render json error bypasses ExceptionHandling</trigger>
    <trigger>singular error key instead of errors array</trigger>
    <trigger>render json without status defaults to 200</trigger>
    <trigger>custom error renderer duplicates framework</trigger>
    <trigger>inconsistent error response format across endpoints</trigger>
    <trigger>success false field in error response</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="manual_error_rendering" confidence="high">
      <signature>render\s+json:.*\berror\b:</signature>
      <description>
        A controller manually rendering a JSON response with an
        `error` key. This bypasses the ExceptionHandling concern,
        produces a non-standard response format (singular `error`
        instead of `errors` array), and typically omits the HTTP
        status code (defaulting to 200 OK).
      </description>
      <example>render json: { error: 'icn and/or clientId is missing' }</example>
      <example>render json: { error: 'Unable to load cemetery data' }, status: :internal_server_error</example>
      <example>render json: { error: 'Invalid year' }, status: :unprocessable_entity</example>
    </pattern>
    <pattern name="render_error_without_status" confidence="high">
      <signature>render\s+json:.*\berror\b.*(?!status)</signature>
      <description>
        A render with an error key but no explicit status code. Rails
        defaults to 200 OK, so the client receives an error body with
        a success status code. CDN caches it. Monitoring counts it as
        success. The error is invisible.
      </description>
      <example>render json: { error: 'icn and/or clientId is missing' }</example>
      <example>render json: { error: 'Something went wrong' }</example>
    </pattern>
    <pattern name="custom_error_renderer_method" confidence="high">
      <signature>def\s+render_error</signature>
      <description>
        A custom `render_error` method defined in a controller. This
        duplicates the functionality of the ExceptionHandling concern,
        introduces inconsistent formatting, and bypasses centralized
        APM/Sentry integration.
      </description>
      <example>def render_error(error)</example>
      <example>def render_error(record)</example>
      <example>def render_validation_error(record)</example>
    </pattern>
    <pattern name="success_false_field" confidence="medium">
      <signature>success:\s*false</signature>
      <description>
        A custom `success: false` field in a JSON error response. The
        HTTP status code already indicates failure; a redundant
        boolean field creates a non-standard format that clients must
        handle specially. Medium confidence because this pattern can
        appear in non-error contexts.
      </description>
      <example>render json: { success: false, error_type: 'validation_error', errors: record.errors.to_hash(true) }</example>
    </pattern>
    <heuristic>
      A controller action that rescues an exception and calls
      `render json:` with an `error` or `errors` key instead of re-
      raising a `Common::Exceptions` class is bypassing the central
      renderer. The ExceptionHandling concern should handle all
      error rendering.
    </heuristic>
    <heuristic>
      Multiple `def render_*_error` methods in a controller or
      concern indicate the team has built a parallel error rendering
      system. Each custom renderer drifts further from the standard
      format and duplicates APM integration logic.
    </heuristic>
    <heuristic>
      A `render json:` call in a controller that does not include
      `:status` will default to 200 OK. When the body contains error
      information, this creates a mismatch between status code and
      content that breaks monitoring and CDN caching.
    </heuristic>
    <false_positive>
      `render json: { error: ... }` in test helpers or spec support
      files that simulate error responses for client testing. These
      are not production controllers and do not bypass
      ExceptionHandling.
    </false_positive>
    <false_positive>
      `render json: { errors: ... }` inside the ExceptionHandling
      concern itself or its supporting classes. The central renderer
      legitimately builds error responses — this is the intended
      pathway, not a bypass.
    </false_positive>
  </detection>

  <rules>
    <rule enforcement="must_not">
      Never manually render error responses in controllers — no
      `render json: { error: ... }` in error paths.
    </rule>
    <rule enforcement="must">
      Always raise typed exceptions from `Common::Exceptions` and
      let ExceptionHandling render the standardized format.
    </rule>
    <rule enforcement="must">
      Always use `errors` array (not singular `error` key) following
      JSON:API specification.
    </rule>
    <rule enforcement="must">
      Always include machine-readable `code` field in error
      responses for programmatic client handling.
    </rule>
    <rule enforcement="must_not">
      Never define custom `render_error` methods in controllers —
      this duplicates ExceptionHandling.
    </rule>
    <rule enforcement="must_not">
      Never use custom fields like `success: false` in error
      responses — HTTP status code indicates failure.
    </rule>
    <rule enforcement="should">
      Return all validation errors in a single response instead of
      failing on the first invalid field.
    </rule>
    <rule enforcement="verify">
      All error responses use `errors:` array (not singular
      `error:`)
    </rule>
    <rule enforcement="verify">
      Each error object has `status`, `code`, `title`, `detail`
      fields
    </rule>
    <rule enforcement="verify">
      Controllers raise exceptions (no manual `render json:` in
      error paths)
    </rule>
    <rule enforcement="verify">
      ExceptionHandling concern handles ALL exceptions (no custom
      renderers)
    </rule>
    <rule enforcement="verify">
      Multiple validation errors returned in single response
    </rule>
    <rule enforcement="verify">
      APM/Sentry captures happen automatically (no manual
      integration code)
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full controller action to understand what error condition triggers the manual render and what exception type best maps to it.</step>
    <step>Check whether the controller already has a custom `render_error` method or concern — the fix may require removing the custom method, not just changing one call site.</step>
    <step>Identify whether the `render json:` call includes a `:status` option. If not, it defaults to 200 OK, which is an additional severity factor.</step>
    <step>Determine the correct `Common::Exceptions` class based on the error type: parameter missing (400), validation failure (422), not found (404), internal error (500), or upstream failure (502/503/504).</step>
    <step>Check if the error path needs to return multiple validation errors. If so, use `Common::Exceptions::ValidationErrors` with an ActiveModel object or construct a multi-error exception. Do not suggest fixes based on the render call alone. The correct typed exception depends on the semantic meaning of the error condition.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>manual render json with error key and no status code (defaults
to 200 OK)</critical>
    <critical>custom render_error method in a controller handling PII, PHI,
or benefits claims</critical>
    <critical>singular error: key in a public-facing API endpoint</critical>
    <high>custom error renderer method that duplicates ExceptionHandling
functionality</high>
    <high>success: false or custom fields in error response format</high>
    <medium>manual render with correct status but wrong format (singular
error instead of errors array)</medium>
  </severity_assessment>

  <default_to_action>
    When you detect manual error rendering with high confidence,
    compose a PR comment that includes: 1. The specific violation
    (which render call bypasses ExceptionHandling) 2. Why it
    matters (inconsistent format, wrong status code, bypasses APM)
    3. The correct `Common::Exceptions` class to raise instead 4.
    A concrete code suggestion using the golden pattern 5. A link
    to this play for full context Do not simply flag the format
    issue -- provide the typed exception replacement. Read the
    error condition to determine the correct exception class
    before suggesting a fix.
  </default_to_action>

  <verify>
    <command description="No manual error rendering remains in changed file">
      grep -On 'render\s+json:.*\berror\b:' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No custom render_error methods remain">
      grep -On 'def\s+render_error' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No success: false fields in responses">
      grep -On 'success:\s*false' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for the changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

  <pr_comment_template>
    **Standardized Error Responses** | `CRITICAL`

    `{{file_path}}:{{line_number}}` -- manual `render json: { error: ... }` bypasses
    ExceptionHandling concern. {{status_note}}

    **Why this matters:** This produces a non-standard error format that clients
    cannot parse with JSON:API libraries. The ExceptionHandling concern provides
    standardized rendering, APM integration, and Sentry capture automatically.

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    **Verify:**
    - [ ] No manual `render json:` in error paths
    - [ ] Uses `Common::Exceptions` typed exception
    - [ ] Response has `errors` array (not singular `error`)
    - [ ] HTTP status code is correct (not 200 OK)
    - [ ] No custom `render_error` methods remain

    [Play: Standardized Error Responses](plays/standardized-error-responses.md)
  </pr_comment_template>

  <anti_pattern_sources>
    <source name="Manual Rendering with Wrong Status" file="app/controllers/v0/profile/connected_applications_controller.rb:18" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/app/controllers/v0/profile/connected_applications_controller.rb#L18" />
    <source name="Custom Error Renderer" file="app/controllers/v0/terms_of_use_agreements_controller.rb:30-40" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/app/controllers/v0/terms_of_use_agreements_controller.rb#L30-L40" />
    <source name="Singular error: String" file="modules/simple_forms_api/app/controllers/simple_forms_api/v1/cemeteries_controller.rb:17" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/simple_forms_api/app/controllers/simple_forms_api/v1/cemeteries_controller.rb#L17" />
    <source name="Custom Format with success: false" file="modules/debts_api/app/controllers/debts_api/v0/digital_disputes_controller.rb:62" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/debts_api/app/controllers/debts_api/v0/digital_disputes_controller.rb#L62" />
    <source name="Multiple Errors with String Array" file="modules/income_limits/app/controllers/income_limits/v1/income_limits_controller.rb:123-131" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/income_limits/app/controllers/income_limits/v1/income_limits_controller.rb#L123-L131" />
  </anti_pattern_sources>

</agent_play>
-->

# Standardized Error Responses: Use Central Renderer with Consistent Format

Every manually rendered error response bypasses the centralized `ExceptionHandling` concern, producing inconsistent formats that force clients to maintain multiple parsers and hide failures from monitoring.

> [!CAUTION]
> Manual `render json: { error: ... }` without a status code defaults to 200 OK, so CDN caches the error and monitoring counts it as a success while the user sees a failure.

## Why It Matters

When you manually render an error response in a controller, you bypass the `ExceptionHandling` concern that provides standardized JSON:API formatting, APM integration, and Sentry capture automatically. Your clients currently face 6 different error formats across 119 endpoints, forcing them to write 6 separate parsers instead of using standard JSON:API libraries. Without machine-readable error codes, clients must parse English strings like `if (msg.includes('Invalid'))`, which breaks the moment message text changes. When you use a singular `error:` key instead of the standard `errors:` array, or omit the HTTP status code entirely, you create invisible failures that monitoring cannot detect and CDN will cache.

> [!IMPORTANT]
> **The Central Renderer EXISTS**: `app/controllers/concerns/exception_handling.rb`
>
> All controllers inherit from `ApplicationController`, which includes the `ExceptionHandling` concern. This concern provides:
>
> - Automatic `rescue_from 'Exception'` that catches ALL exceptions
> - `render_errors(va_exception)` that renders standardized JSON:API format
> - Integration with Sentry, Datadog, and Rails logging
> - Consistent HTTP status codes and error structure
>
> **Don't reinvent the wheel** -- the central renderer does format + logging + APM for you.

## Guidance

Raise typed exceptions from `Common::Exceptions` and let the `ExceptionHandling` concern render the standardized JSON:API response. The concern automatically handles formatting, status codes, APM span errors, Sentry capture, and logging -- no manual rendering needed.

### Do

- Raise typed exceptions and let `ExceptionHandling` render the response
  ```ruby
  raise Common::Exceptions::ParameterMissing.new('icn or client_id')
  ```
- Use `errors` array (not singular `error` key) following JSON:API specification
  ```ruby
  # ExceptionHandling produces:
  # { "errors": [{ "status": "400", "code": "PARAMETER_MISSING", ... }] }
  ```
- Include machine-readable `code` field in error responses for programmatic client handling
- Return all validation errors in a single response
  ```ruby
  raise Common::Exceptions::ValidationErrors.new(form)
  ```

### Don't

- Manually render error responses in controllers
  ```ruby
  # Bad: bypasses ExceptionHandling, may default to 200 OK
  render json: { error: 'icn and/or clientId is missing' }
  ```
- Define custom `render_error` methods in controllers
  ```ruby
  # Bad: duplicates ExceptionHandling functionality
  def render_error(error)
    render json: { errors: [{ title: error.class.to_s }] }, status: :bad_request
  end
  ```
- Use custom fields like `success: false` in error responses
  ```ruby
  # Bad: redundant with HTTP status code
  render json: { success: false, error_type: 'validation_error', errors: record.errors.to_hash(true) }
  ```

## Anti-Patterns

### 1. Manual Rendering with Wrong Status

**Source:** [app/controllers/v0/profile/connected_applications_controller.rb:18](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/app/controllers/v0/profile/connected_applications_controller.rb#L18)

```ruby
def destroy
  icn = @current_user.icn
  client_id = connected_accounts_params[:id]

  if icn.nil? || client_id.nil?
    render json: { error: 'icn and/or clientId is missing' }
    # No status code — Rails defaults to 200 OK!
    # Manual rendering bypasses ExceptionHandling concern
    # Uses singular 'error' instead of 'errors' array
    # Missing: title, code, source.pointer, standardized structure
    return
  end
  # ...
end
```

**Problems:**

- Returns **200 OK** with error body (monitoring thinks it succeeded)
- Response: `{ "error": "..." }` (not using standardized `errors` array)
- No machine-readable error code (client must parse English string)
- Bypasses centralized logging/APM/Sentry integration
- Cannot return multiple validation errors in one response

**Corrected:**

```ruby
def destroy
  icn = @current_user.icn
  client_id = connected_accounts_params[:id]

  if icn.nil? || client_id.nil?
    # Raise typed exception — ExceptionHandling renders standardized format
    raise Common::Exceptions::ParameterMissing.new('icn or client_id')
  end
  # No rescue needed — ExceptionHandling concern handles it!
  # ...
end
```

**JSON response (automatic from ExceptionHandling):**

```json
{
  "errors": [{
    "status": "400",
    "code": "PARAMETER_MISSING",
    "title": "Missing Parameter",
    "detail": "icn or client_id is required",
    "source": { "parameter": "icn" }
  }]
}
```

---

### 2. Custom Error Renderer

**Source:** [app/controllers/v0/terms_of_use_agreements_controller.rb:30-40](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/app/controllers/v0/terms_of_use_agreements_controller.rb#L30-L40)

```ruby
def render_error(error)
  render json: {
    errors: [
      {
        title: error.class.to_s,
        detail: error.message,
        code: 'TERMSOFUSE400',
        status: '400'
      }
    ]
  }, status: :bad_request
  # Custom renderer duplicates ExceptionHandling concern
  # Custom code 'TERMSOFUSE400' not following standard naming
  # Bypasses APM/Sentry integration (no span.set_error, no Sentry capture)
  # Manual backtrace logging duplicates what APM captures
end
```

**Problems:**

- Duplicates functionality that ExceptionHandling provides
- Custom error codes (`TERMSOFUSE400`) instead of standard codes
- Bypasses centralized error handling (no APM span errors, no Sentry)
- Team maintains custom renderer instead of using framework
- Inconsistent with other endpoints using ExceptionHandling

**Corrected:**

```ruby
def accept
  service.create_agreement!(@current_user)
  render json: @current_user, status: :created
rescue TermsOfUse::Errors::DuplicateError => e
  # Just raise a Common::Exception — ExceptionHandling does the rest
  raise Common::Exceptions::UnprocessableEntity.new(
    detail: 'Agreement already exists',
    source: 'TermsOfUse.create_agreement',
    cause: e
  )
end

# No custom render_error method needed!
# ExceptionHandling concern automatically:
# - Renders standardized JSON:API format
# - Logs to Rails, Sentry, APM
# - Sets correct HTTP status
# - Includes backtrace, cause chain
```

---

### 3. Singular `error:` String

**Source:** [modules/simple_forms_api/app/controllers/simple_forms_api/v1/cemeteries_controller.rb:17](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/simple_forms_api/app/controllers/simple_forms_api/v1/cemeteries_controller.rb#L17)

```ruby
rescue => e
  Rails.logger.error "Cemetery controller error: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")
  render json: { error: 'Unable to load cemetery data' }, status: :internal_server_error
  # Singular 'error:' instead of 'errors:' array
  # Missing: machine-readable error code, structured fields
  # Manual backtrace logging duplicates APM capture
end
```

**Problems:**

- Singular `error:` key (not standard `errors:` array)
- No machine-readable error code
- Can't return multiple errors in one response
- Manual backtrace logging duplicates what APM already captures
- Client can't use standard JSON:API parsing libraries

**Corrected:**

```ruby
rescue => e
  raise Common::Exceptions::InternalServerError.new(
    detail: 'Unable to load cemetery data',
    source: 'CemeteriesController#index',
    cause: e  # Preserves original exception for APM
  )
  # ExceptionHandling automatically:
  # - Logs to Rails.logger (with correct level)
  # - Captures to Sentry (for 5xx)
  # - Sets APM span error (for 5xx)
  # - Logs backtrace (no manual logging needed)
  # - Renders standardized format
end
```

**JSON response (automatic):**

```json
{
  "errors": [{
    "status": "500",
    "code": "INTERNAL_SERVER_ERROR",
    "title": "Internal Server Error",
    "detail": "Unable to load cemetery data",
    "meta": {
      "source": "CemeteriesController#index"
    }
  }]
}
```

---

### 4. Custom Format with `success: false`

**Source:** [modules/debts_api/app/controllers/debts_api/v0/digital_disputes_controller.rb:62](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/debts_api/app/controllers/debts_api/v0/digital_disputes_controller.rb#L62)

```ruby
def render_validation_error(record)
  render json: {
    success: false,  # Custom field violates standardized format
    error_type: 'validation_error',
    errors: record.errors.to_hash(true)  # Hash format, not structured objects
  }, status: :unprocessable_entity
end
```

**Problems:**

- Custom `success: false` field (status code already indicates failure)
- `errors` is a hash, not array of structured error objects
- Missing standard fields (`code`, `title`, `source.pointer`)
- Client must check both status code AND `success` field (redundant)

**Corrected:**

```ruby
def create
  form = DigitalDisputeForm.new(params)

  unless form.valid?
    # Raise ValidationErrors with ActiveModel errors
    raise Common::Exceptions::ValidationErrors.new(form)
  end

  # ExceptionHandling automatically converts to:
  # {
  #   "errors": [
  #     {
  #       "status": "422",
  #       "code": "VALIDATION_ERROR",
  #       "title": "Validation Error",
  #       "detail": "Email is invalid",
  #       "source": { "pointer": "/data/attributes/email" }
  #     }
  #   ]
  # }

  service.create_dispute(form)
  render json: form, status: :created
end
```

---

### 5. Multiple Errors with String Array

**Source:** [modules/income_limits/app/controllers/income_limits/v1/income_limits_controller.rb:123-131](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/income_limits/app/controllers/income_limits/v1/income_limits_controller.rb#L123-L131)

```ruby
def render_invalid_year_error
  render json: { error: 'Invalid year' }, status: :unprocessable_entity
  # If user has BOTH invalid year AND invalid zipcode, can only return ONE error
end

def render_invalid_dependents_error
  render json: { error: 'Invalid dependents' }, status: :unprocessable_entity
  # Separate methods = can't return multiple validation errors at once
end
```

**Problems:**

- Only ONE error can be returned (first failure)
- No error codes for programmatic handling
- Client gets "whack-a-mole" UX (fix one field, submit, discover another field invalid)

**Corrected:**

```ruby
def index
  # Validate all parameters at once
  errors = []
  errors << { field: :year, message: 'Invalid year' } unless valid_year?(params[:year])
  errors << { field: :zipcode, message: 'Invalid zipcode' } unless valid_zipcode?(params[:zipcode])
  errors << { field: :dependents, message: 'Invalid dependents count' } unless valid_dependents?(params[:dependents])

  if errors.any?
    # Create validation errors with all failures
    exception = Common::Exceptions::UnprocessableEntity.new(detail: 'Validation failed')
    exception.errors = errors.map do |err|
      {
        status: '422',
        code: 'VALIDATION_ERROR',
        title: 'Validation Error',
        detail: err[:message],
        source: { parameter: err[:field] }
      }
    end
    raise exception
  end

  # ExceptionHandling renders ALL validation errors in single response:
  # {
  #   "errors": [
  #     { "status": "422", "detail": "Invalid year", "source": { "parameter": "year" } },
  #     { "status": "422", "detail": "Invalid zipcode", "source": { "parameter": "zipcode" } }
  #   ]
  # }

  render json: income_limits_data
end
```

## Reference

### Current State: Fragmentation

**6 distinct error rendering patterns** across **119 endpoints**:

| Pattern | Count | Standard Compliant? | Fields Present |
|---------|-------|---------------------|----------------|
| **1. Singular `error:` string** | 83 files | No | None |
| **2. `errors:` array of strings** | ~56 files | Partial | `errors` (wrong type) |
| **3. Custom `render` (title/detail)** | ~30 files | Close | `title`, `detail` |
| **4. LighthouseErrorHandler** | ~5 files | Close | `title`, `status`, `detail` |
| **5. JSON:API (ExceptionHandling)** | ~30% | **Compliant** | `status`, `code`, `title`, `detail`, `source.pointer` |
| **6. One-off custom formats** | ~10 files | No | Various |

**The Problem:**

- ~30% use ExceptionHandling concern (standardized JSON:API format)
- ~70% manually render errors (6 different non-standard formats)
- 15+ controllers bypass framework with manual `render json: {}`

### Impact

**Without central renderer + standardized format:**

- 119 endpoints use 6 different formats -- clients need 6 parsers
- Missing error codes -- clients parse English strings (`if msg.includes('Invalid')`)
- Can't use standard JSON:API client libraries
- Manual rendering returns 200 OK (monitoring sees success when error occurred)
- Multiple validation errors require multiple requests (whack-a-mole UX)
- Bypasses APM/Sentry/logging integration (no centralized telemetry)
- Manual backtrace logging duplicates what APM captures
- Each team reinvents error handling (15+ custom renderers)

**With central renderer + standardized format:**

- ONE format across all endpoints -- clients use standard parsers
- Machine-readable codes enable programmatic error handling
- JSON:API client libraries work out of the box
- Correct HTTP status codes (monitoring tracks errors accurately)
- All validation errors in single response (better UX)
- Automatic APM/Sentry/logging (no manual integration needed)
- Backtrace captured once by APM (no duplication)
- Zero custom code -- ExceptionHandling does everything

## References

- [JSON:API Error Objects](https://jsonapi.org/format/#error-objects)
