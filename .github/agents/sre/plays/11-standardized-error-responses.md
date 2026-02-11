# Play 11: Standardized Error Responses -- Use Central Renderer with Consistent Format

## Context
With 119 endpoints returning 6 different error formats, clients need 6 separate parsers and cannot use standard error-handling libraries. Over 15 manual renders bypass ExceptionHandling and return 200 OK with an error body, so CDN caches it and monitoring sees success when there is a failure. Without error codes, clients must parse English strings like `if (msg.includes('Invalid'))`, which breaks when translations change the message text.

## Applies To
- `app/controllers/**/*.rb`
- `modules/*/app/controllers/**/*.rb`

## Investigation Steps
1. Read the full controller action to understand what error condition triggers the manual render and what exception type best maps to it.
2. Check whether the controller already has a custom `render_error` method or concern -- the fix may require removing the custom method, not just changing one call site.
3. Identify whether the `render json:` call includes a `:status` option. If not, it defaults to 200 OK, which is an additional severity factor.
4. Determine the correct `Common::Exceptions` class based on the error type: parameter missing (400), validation failure (422), not found (404), internal error (500), or upstream failure (502/503/504).
5. Check if the error path needs to return multiple validation errors. If so, use `Common::Exceptions::ValidationErrors` with an ActiveModel object or construct a multi-error exception.

## Severity Assessment
- **CRITICAL:** Manual render json with error key and no status code (defaults to 200 OK)
- **CRITICAL:** Custom `render_error` method in a controller handling PII, PHI, or benefits claims
- **CRITICAL:** Singular `error:` key in a public-facing API endpoint
- **HIGH:** Custom error renderer method that duplicates ExceptionHandling functionality
- **HIGH:** `success: false` or custom fields in error response format
- **MEDIUM:** Manual render with correct status but wrong format (singular error instead of errors array)

## Golden Patterns

### Do
Raise typed exceptions and let `ExceptionHandling` render the response:
```ruby
raise Common::Exceptions::ParameterMissing.new('icn or client_id')
```

Use `errors` array (not singular `error` key) following JSON:API specification:
```ruby
# ExceptionHandling produces:
# { "errors": [{ "status": "400", "code": "PARAMETER_MISSING", ... }] }
```

Include machine-readable `code` field for programmatic client handling.

Return all validation errors in a single response:
```ruby
raise Common::Exceptions::ValidationErrors.new(form)
```

### Don't
Never manually render error responses in controllers:
```ruby
# BAD: bypasses ExceptionHandling, may default to 200 OK
render json: { error: 'icn and/or clientId is missing' }
```

Never define custom `render_error` methods in controllers:
```ruby
# BAD: duplicates ExceptionHandling functionality
def render_error(error)
  render json: { errors: [{ title: error.class.to_s }] }, status: :bad_request
end
```

Never use custom fields like `success: false` in error responses:
```ruby
# BAD: redundant with HTTP status code
render json: { success: false, error_type: 'validation_error', errors: record.errors.to_hash(true) }
```

## Anti-Patterns

### Manual Rendering with Wrong Status
**Anti-pattern:**
```ruby
def destroy
  icn = @current_user.icn
  client_id = connected_accounts_params[:id]

  if icn.nil? || client_id.nil?
    render json: { error: 'icn and/or clientId is missing' }
    # No status code -- Rails defaults to 200 OK!
    return
  end
end
```
**Problem:** Returns 200 OK with error body. Monitoring thinks it succeeded. Uses singular `error` instead of `errors` array. No machine-readable error code. Bypasses centralized logging/APM/Sentry integration.

**Corrected:**
```ruby
def destroy
  icn = @current_user.icn
  client_id = connected_accounts_params[:id]

  if icn.nil? || client_id.nil?
    raise Common::Exceptions::ParameterMissing.new('icn or client_id')
  end
  # ExceptionHandling renders standardized format automatically
end
```

### Custom Error Renderer
**Anti-pattern:**
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
end
```
**Problem:** Duplicates ExceptionHandling functionality. Custom error codes not following standard naming. Bypasses centralized error handling (no APM span errors, no Sentry). Inconsistent with other endpoints.

**Corrected:**
```ruby
def accept
  service.create_agreement!(@current_user)
  render json: @current_user, status: :created
rescue TermsOfUse::Errors::DuplicateError => e
  raise Common::Exceptions::UnprocessableEntity.new(
    detail: 'Agreement already exists',
    source: 'TermsOfUse.create_agreement',
    cause: e
  )
end
# No custom render_error method needed!
```

### Singular error: String
**Anti-pattern:**
```ruby
rescue => e
  Rails.logger.error "Cemetery controller error: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")
  render json: { error: 'Unable to load cemetery data' }, status: :internal_server_error
end
```
**Problem:** Singular `error:` key (not standard `errors:` array). No machine-readable error code. Manual backtrace logging duplicates what APM already captures. Client cannot use standard JSON:API parsing libraries.

**Corrected:**
```ruby
rescue => e
  raise Common::Exceptions::InternalServerError.new(
    detail: 'Unable to load cemetery data',
    source: 'CemeteriesController#index',
    cause: e
  )
  # ExceptionHandling automatically logs, captures to Sentry, sets APM span error
end
```

### Custom Format with success: false
**Anti-pattern:**
```ruby
def render_validation_error(record)
  render json: {
    success: false,
    error_type: 'validation_error',
    errors: record.errors.to_hash(true)
  }, status: :unprocessable_entity
end
```
**Problem:** Custom `success: false` field is redundant with HTTP status code. `errors` is a hash, not array of structured error objects. Missing standard fields (`code`, `title`, `source.pointer`).

**Corrected:**
```ruby
def create
  form = DigitalDisputeForm.new(params)

  unless form.valid?
    raise Common::Exceptions::ValidationErrors.new(form)
  end

  service.create_dispute(form)
  render json: form, status: :created
end
```

### Multiple Errors with String Array
**Anti-pattern:**
```ruby
def render_invalid_year_error
  render json: { error: 'Invalid year' }, status: :unprocessable_entity
end

def render_invalid_dependents_error
  render json: { error: 'Invalid dependents' }, status: :unprocessable_entity
end
```
**Problem:** Only ONE error can be returned per request. No error codes for programmatic handling. Client gets "whack-a-mole" UX -- fix one field, submit, discover another field invalid.

**Corrected:**
```ruby
def index
  errors = []
  errors << { field: :year, message: 'Invalid year' } unless valid_year?(params[:year])
  errors << { field: :zipcode, message: 'Invalid zipcode' } unless valid_zipcode?(params[:zipcode])
  errors << { field: :dependents, message: 'Invalid dependents count' } unless valid_dependents?(params[:dependents])

  if errors.any?
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

  render json: income_limits_data
end
```

## Finding Template
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

## Verify Commands
```bash
# No manual error rendering remains in changed file
grep -On 'render\s+json:.*\berror\b:' {{file_path}} && exit 1 || exit 0

# No custom render_error methods remain
grep -On 'def\s+render_error' {{file_path}} && exit 1 || exit 0

# No success: false fields in responses
grep -On 'success:\s*false' {{file_path}} && exit 1 || exit 0

# Run specs for the changed file
bundle exec rspec {{spec_path}}

# RuboCop passes for changed file
bundle exec rubocop {{file_path}}
```

## Related Plays
- Play: Classify Errors (prerequisite)
- Play: Stable Unique Error Codes (complementary)
- Play: Never Return 2xx with Errors (complementary)
