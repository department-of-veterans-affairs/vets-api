---
id: standardized-error-responses
title: 'Standardized Error Responses: Use Central Renderer with Consistent Format'
severity: CRITICAL
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

  <rules>
    <rule enforcement="must">
      Raise typed exceptions from `Common::Exceptions` and let
      ExceptionHandling render responses — no manual
      `render json: { error: ... }` or custom `render_error`
      methods in error paths.
    </rule>
    <rule enforcement="must">
      Use `errors` array (not singular `error` key) following
      JSON:API specification, with machine-readable `code` field
      for programmatic client handling.
    </rule>
    <rule enforcement="must">
      Use HTTP status codes as the sole indicator of success or
      failure — no custom `success: false` envelope fields.
    </rule>
    <rule enforcement="should">
      Return all validation errors in a single response instead of
      failing on the first invalid field.
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full controller action to understand what error condition triggers the manual render and what exception type best maps to it.</step>
    <step>Check whether the controller already has a custom `render_error` method or concern — the fix may require removing the custom method, not just changing one call site.</step>
    <step>Identify whether the `render json:` call includes a `:status` option. If not, it defaults to 200 OK, which is an additional severity factor.</step>
    <step>Determine the correct `Common::Exceptions` class based on the error type: parameter missing (400), validation failure (422), not found (404), internal error (500), or upstream failure (502/503/504). Verify the constructor signature against the API Reference in sre.agent.md before writing the recommendation.</step>
    <step>Check if the error path needs to return multiple validation errors. If so, use `Common::Exceptions::ValidationErrors` with an ActiveModel object or construct a multi-error exception. Do not suggest fixes based on the render call alone. The correct typed exception depends on the semantic meaning of the error condition.</step>
    <step>**Check for business logic in custom render methods.** If a custom `render_errors` or `render_error` method contains business logic beyond rendering (e.g., modifying error messages, conditionally adjusting error details based on field names), the recommendation must account for preserving that logic. Do not simply say "remove the method and raise instead" — explain where the business logic should move to (e.g., into a before_action validation, a custom exception class, or a concern).</step>
    <step>**Flag ALL manual renders in the controller, not just the broadest rescue.** If a controller has multiple rescue clauses that each manually render errors, flag each one individually. A controller with 5 manual renders is 5 violations, not 1.</step>
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

    [Play: Standardized Error Responses](11-standardized-error-responses.md)
  </pr_comment_template>

</agent_play>
-->

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

### 2. Custom Error Renderer

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

**Corrected:**

```ruby
def accept
  service.create_agreement!(@current_user)
  render json: @current_user, status: :created
rescue TermsOfUse::Errors::DuplicateError
  # Just raise a Common::Exception — ExceptionHandling does the rest
  # Ruby automatically preserves the cause chain within rescue blocks
  raise Common::Exceptions::UnprocessableEntity.new(
    detail: 'Agreement already exists',
    source: 'TermsOfUse.create_agreement'
  )
end

# No custom render_error method needed!
# ExceptionHandling concern automatically:
# - Renders standardized JSON:API format
# - Logs to Rails, Sentry, APM
# - Sets correct HTTP status
# - Includes backtrace, cause chain (via Ruby's implicit $!.cause)
```

### 3. Singular `error:` String

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

**Corrected:**

```ruby
rescue => e
  # InternalServerError takes a single Exception argument
  raise Common::Exceptions::InternalServerError.new(e)
  # ExceptionHandling automatically:
  # - Logs to Rails.logger (with correct level)
  # - Captures to Sentry (for 5xx)
  # - Sets APM span error (for 5xx)
  # - Logs backtrace (no manual logging needed)
  # - Renders standardized format
end
```

### 4. Custom Format with `success: false`

```ruby
def render_validation_error(record)
  render json: {
    success: false,  # Custom field violates standardized format
    error_type: 'validation_error',
    errors: record.errors.to_hash(true)  # Hash format, not structured objects
  }, status: :unprocessable_entity
end
```

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

### 5. Multiple Errors with String Array

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
