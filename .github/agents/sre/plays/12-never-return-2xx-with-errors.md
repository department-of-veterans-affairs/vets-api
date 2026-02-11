# Play 12: Never Return 2xx with Errors

## Context
When an error returns 200 OK, the CDN caches the error response and every user receives the cached error for five minutes, causing cascading failures. Dashboards show 100% success even though 30% of requests are failing, so metrics become useless and incidents go undetected. The client sees 200, assumes success, and does not retry, so the user's request fails but the UI shows "Success." APM sees 200 with no alert firing and no on-call engineer paged.

## Applies To
- `app/controllers/**/*.rb`
- `modules/*/app/controllers/**/*.rb`

## Investigation Steps
1. Read the full controller action to understand the error condition being handled (missing parameter, validation failure, upstream error, etc.).
2. Determine the correct HTTP status code for the error type.
3. Check whether the controller uses the `ExceptionHandling` concern. If so, determine whether raising a `Common::Exceptions` error would be better than manually rendering JSON.
4. Check for custom envelope fields (`success`, `error_type`, `status` in body) that should be replaced with the standardized error format.
5. Verify whether other actions in the same controller have consistent error handling. Flag inconsistencies across the controller.

## Severity Assessment
- **CRITICAL:** `render json` with error body returns 200 OK -- CDN will cache the error, cascading to all users
- **CRITICAL:** Error response with 200 status in controller handling PII, PHI, or benefits claims data
- **HIGH:** Custom `success: false` field in response body with correct status code -- violates standardized format
- **HIGH:** Inconsistent status codes across actions in the same controller for the same error type
- **MEDIUM:** Ad-hoc error hash format instead of standardized errors array (style violation, not semantic)

## Golden Patterns

### Do
Include explicit `status:` on every `render json:` in error paths:
```ruby
render json: { errors: [{ status: "400", detail: "Missing parameter" }] },
       status: :bad_request
```

Use 4xx for client errors and 5xx for server errors:
```ruby
render json: { errors: [...] }, status: :not_found         # 404
render json: { errors: [...] }, status: :bad_gateway        # 502
```

Use the standardized error format with `errors` array:
```ruby
render json: {
  errors: [{
    status: "422",
    code: "INVALID_ATTRIBUTE",
    title: "Validation Error",
    detail: "Email is invalid"
  }]
}, status: :unprocessable_entity
```

### Don't
Never return 200 OK when the response body contains an error:
```ruby
# BAD: Rails defaults to 200 OK when status: is omitted
render json: { error: 'icn and/or clientId is missing' }
```

Never use custom `success: false` fields -- HTTP status codes are the sole indicator:
```ruby
# BAD: redundant boolean field; clients must check both status and body
render json: { success: false, error_type: 'validation_error' },
       status: :unprocessable_entity
```

Never omit the `status:` parameter on error renders:
```ruby
# BAD: defaults to 200
render json: { errors: ['not found'] }
```

## Anti-Patterns

### Connected Applications Controller
**Anti-pattern:**
```ruby
def destroy
  icn = @current_user.icn
  client_id = connected_accounts_params[:id]

  if icn.nil? || client_id.nil?
    render json: { error: 'icn and/or clientId is missing' }
    # CRITICAL: No status: parameter -- Rails defaults to 200 OK!
    return
  end
end
```
**Problem:** Returns 200 OK with error body. CDN/cache may cache this error response. Client thinks request succeeded (200 = success per RFC 7231). Monitoring dashboards count this as successful. APM tools do not classify as error. Client retry logic will not trigger.

**Corrected:**
```ruby
def destroy
  icn = @current_user.icn
  client_id = connected_accounts_params[:id]

  if icn.nil? || client_id.nil?
    render json: {
      errors: [{
        status: "400",
        code: "MISSING_PARAMETER",
        title: "Missing Parameter",
        detail: "ICN and client ID are required"
      }]
    }, status: :bad_request
    return
  end
end
```

### Digital Disputes Controller
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
**Problem:** Custom `success: false` field violates standardized error structure. Clients must check both status code AND `success` field (redundant). `errors` hash format incompatible with standard parsers.

**Corrected:**
```ruby
def render_validation_error(record)
  errors = record.errors.map do |field, messages|
    {
      status: "422",
      code: "INVALID_ATTRIBUTE",
      title: "Validation Error",
      detail: "#{field}: #{messages.join(', ')}",
      source: { pointer: "/data/attributes/#{field}" }
    }
  end

  render json: { errors: errors }, status: :unprocessable_entity
end
```

## Finding Template
**Never Return 2xx with Errors** | `HIGH`

`{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

**Why this matters:** Returning 200 OK with an error body breaks CDN caching
(error gets cached as success), monitoring (dashboards show 100% success),
client behavior (no retry triggered), and APM (no alert fires). The error
becomes invisible to every automated system.

**Suggested fix:**
```ruby
{{suggested_code}}
```

**Verify:**
- [ ] Explicit `status:` on every `render json:` in error paths
- [ ] No 200 responses containing error/errors fields
- [ ] No custom `success: false` envelope fields
- [ ] Specs assert correct error status codes

[Play: Never Return 2xx with Errors](plays/never-return-2xx-with-errors.md)

## Verify Commands
```bash
# No render json with error but without status in changed file
grep -On 'render\s+json:.*error(?!.*status)' {{file_path}} && exit 1 || exit 0

# No success false field in responses
grep -On 'success:\s*false' {{file_path}} && exit 1 || exit 0

# Run specs for changed file
bundle exec rspec {{spec_path}}

# RuboCop passes for changed file
bundle exec rubocop {{file_path}}
```

## Related Plays
- Play: Classify Errors (prerequisite)
- Play: Standardized Error Responses (complementary)
