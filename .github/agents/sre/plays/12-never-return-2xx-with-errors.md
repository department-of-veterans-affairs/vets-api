---
id: never-return-2xx
title: Never Return 2xx with Errors
severity: HIGH
---

<!--
<agent_play>

  <context>
    When an error returns 200 OK, the CDN caches the error response and
    every user receives the cached error for five minutes, causing
    cascading failures. Dashboards show 100% success even though 30% of
    requests are failing, so metrics become useless and incidents go
    undetected. The client sees 200, assumes success, and does not
    retry, so the user's request fails but the UI shows "Success." APM
    sees 200 with no alert firing and no on-call engineer paged, so the
    issue is discovered hours later through user complaints.
  </context>

  <applies_to>
    <glob>app/controllers/**/*.rb</glob>
    <glob>modules/*/app/controllers/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="classify-errors" relationship="prerequisite" />
    <play id="standardized-error-responses" relationship="complementary" />
  </related_plays>

  <rules>
    <rule enforcement="must">
      Every `render json:` call in an error path MUST include an
      explicit `status:` parameter — Rails defaults to 200 OK.
    </rule>
    <rule enforcement="must_not">
      Never return 200 OK, 201 Created, or any 2xx status code when
      the response body contains an error.
    </rule>
    <rule enforcement="must_not">
      Never use custom `success: false` fields in response bodies —
      HTTP status codes are the sole indicator of success or
      failure.
    </rule>
    <rule enforcement="must">
      Use 4xx status codes for client errors (bad request,
      validation, not found) and 5xx for server errors (upstream
      failures, internal errors).
    </rule>
    <rule enforcement="should">
      Use the standardized error response format with `errors` array
      of structured objects, not ad-hoc error hashes.
    </rule>
    <rule enforcement="verify">
      All error responses have explicit status parameter
    </rule>
    <rule enforcement="verify">
      No 200 responses containing error/success fields
    </rule>
    <rule enforcement="verify">
      Monitoring dashboards count errors accurately
    </rule>
    <rule enforcement="verify">
      CDN doesn't cache error responses
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full controller action to understand the error condition being handled (missing parameter, validation failure, upstream error, etc.).</step>
    <step>Determine the correct HTTP status code for the error type:</step>
    <step>Check whether the controller uses the `ExceptionHandling` concern. If so, determine whether raising a `Common::Exceptions` error would be better than manually rendering JSON.</step>
    <step>Check for custom envelope fields (`success`, `error_type`, `status` in body) that should be replaced with the standardized error format.</step>
    <step>Verify whether other actions in the same controller have consistent error handling. Flag inconsistencies across the controller.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>render json with error body returns 200 OK — CDN will cache
the error, cascading to all users</critical>
    <critical>error response with 200 status in controller handling PII,
PHI, or benefits claims data</critical>
    <high>custom success: false field in response body with correct
status code — violates standardized format</high>
    <high>inconsistent status codes across actions in the same
controller for the same error type</high>
    <medium>ad-hoc error hash format instead of standardized errors array
(style violation, not semantic)</medium>
  </severity_assessment>

  <pr_comment_template>
    **Never Return 2xx with Errors** | `HIGH`

    `{{file_path}}:{{line_number}}` — {{one_line_violation_description}}

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

    [Play: Never Return 2xx with Errors](12-never-return-2xx-with-errors.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- Include explicit `status:` on every `render json:` in error paths:
  ```ruby
  render json: { errors: [{ status: "400", detail: "Missing parameter" }] },
         status: :bad_request
  ```
- Use 4xx for client errors (bad request, validation, not found) and 5xx for server errors (upstream failures, internal errors):
  ```ruby
  render json: { errors: [...] }, status: :not_found         # 404
  render json: { errors: [...] }, status: :bad_gateway        # 502
  ```
- Use the standardized error format with `errors` array:
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

- Return 200 OK when the response body contains an error:
  ```ruby
  # BAD: Rails defaults to 200 OK when status: is omitted
  render json: { error: 'icn and/or clientId is missing' }
  ```
- Use custom `success: false` fields -- HTTP status codes are the sole indicator of success or failure:
  ```ruby
  # BAD: redundant boolean field; clients must check both status and body
  render json: { success: false, error_type: 'validation_error' },
         status: :unprocessable_entity
  ```
- Omit the `status:` parameter on `render json:` calls in error paths:
  ```ruby
  # BAD: defaults to 200
  render json: { errors: ['not found'] }
  ```

## Anti-Patterns

#### Connected Applications Controller

##### Anti-Pattern

```ruby
def destroy
  icn = @current_user.icn
  client_id = connected_accounts_params[:id]

  if icn.nil? || client_id.nil?
    render json: { error: 'icn and/or clientId is missing' }
    # [!!] CRITICAL: No status: parameter — Rails defaults to 200 OK!
    return
  end
  # ...
end
```

##### Golden Pattern

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
    }, status: :bad_request  # Explicit 400 status
    return
  end
  # ...
end
```

#### Digital Disputes Controller

##### Anti-Pattern

```ruby
def render_validation_error(record)
  render json: {
    success: false,  # Custom field violates standardized format
    error_type: 'validation_error',
    errors: record.errors.to_hash(true)  # Hash format, not structured error objects
  }, status: :unprocessable_entity
end
```

##### Golden Pattern

```ruby
def render_validation_error(record)
  errors = record.errors.map do |field, messages|
    {
      status: "422",
      code: "INVALID_ATTRIBUTE",
      title: "Validation Error",
      detail: "#{field}: #{messages.join(', ')}",
      source: { pointer: "/data/attributes/#{field}" }  # JSON Pointer to field
    }
  end

  render json: { errors: errors }, status: :unprocessable_entity
end
```
