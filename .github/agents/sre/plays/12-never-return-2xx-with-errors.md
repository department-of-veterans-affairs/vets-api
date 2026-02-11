---
id: never-return-2xx
title: Never Return 2xx with Errors
version: 1
severity: HIGH
category: http-status
tags:
- 2xx-with-errors
- http-status
- render-status
- caching
- monitoring
language: ruby
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

  <retrieval_triggers>
    <trigger>render json error without status code defaults to 200</trigger>
    <trigger>success false in response body with 200 status</trigger>
    <trigger>error response cached by CDN as successful</trigger>
    <trigger>monitoring shows 100% success but errors exist</trigger>
    <trigger>client thinks request succeeded but it failed</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="render_error_without_status" confidence="high">
      <signature>render\s+json:.*error.*(?!status)</signature>
      <description>
        A `render json:` call whose body contains an error key or
        error message but does not include a `status:` parameter.
        Rails defaults to 200 OK when no status is given, so this
        returns a success status code for an error response.
      </description>
      <example>render json: { error: 'icn and/or clientId is missing' }</example>
      <example>render json: { error: e.message }</example>
      <example>render json: { errors: ['not found'] }</example>
    </pattern>
    <pattern name="custom_success_false_field" confidence="medium">
      <signature>success:\s*false</signature>
      <description>
        A response body containing a custom `success: false` field.
        Even when paired with a correct HTTP status code, this
        violates the standardized error response format. The HTTP
        status code alone should convey success or failure. Medium
        confidence because `success: false` with a correct 4xx/5xx
        status is a style violation, while `success: false` with 200
        is a critical violation.
      </description>
      <example>render json: { success: false, error_type: 'validation_error' }, status: :unprocessable_entity</example>
      <example>render json: { success: false, message: 'failed' }</example>
    </pattern>
    <pattern name="render_error_no_status_multiline" confidence="high">
      <signature>render\s+json:.*\berror\b.*$</signature>
      <description>
        A `render json:` call with an error-related key. After
        matching, check the same line and the next line for a
        `status:` parameter. If no `status:` is present on either
        line, this is a high-confidence violation because Rails will
        default to 200 OK.
      </description>
      <example>render json: { error: 'missing parameter' }</example>
      <example>render json: { errors: record.errors.to_hash(true) }</example>
    </pattern>
    <heuristic>
      A controller action that renders JSON containing error,
      errors, or message keys without an explicit `status:`
      parameter is a high-priority violation. Rails defaults to 200
      OK, which means the error response will be treated as
      successful by CDNs, monitoring, and client retry logic.
    </heuristic>
    <heuristic>
      A response body containing `success: false` or `success: true`
      fields indicates a custom envelope that violates the
      standardized error format. HTTP status codes should be the
      sole indicator of success or failure, not body-level boolean
      fields.
    </heuristic>
    <heuristic>
      A controller that returns different status codes for the same
      error type across different actions (e.g., 200 in one action,
      422 in another for validation errors) signals inconsistent
      status code usage. Check all error paths in the controller.
    </heuristic>
    <false_positive>
      `render json: { error: 'not found' }, status: :not_found` —
      the `status:` parameter is present and correct. This is not a
      violation even though it matches the error keyword pattern.
      Verify that `status:` appears on the same line or the
      immediately following line.
    </false_positive>
    <false_positive>
      `render json: { data: results, meta: { errors: warnings } },
      status: :ok` — a 200 response with a `meta.errors` field
      containing non-fatal warnings (not request failures) is
      acceptable when the primary request succeeded and the warnings
      are informational.
    </false_positive>
  </detection>

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

  <default_to_action>
    When you detect a 2xx-with-errors violation with high
    confidence, compose a PR comment that includes: 1. The
    specific violation (which render call is missing `status:` and
    where) 2. Why it matters (CDN caching, monitoring blindness,
    client deception — draw from context/why_it_matters) 3. A
    concrete code suggestion with the correct `status:` parameter
    and standardized error format 4. The verification checklist
    items relevant to this specific case 5. A link to this play
    for full context Do not simply flag the violation — provide
    the fix. Read the controller action to determine the correct
    status code before suggesting a replacement.
  </default_to_action>

  <verify>
    <command description="No render json with error but without status in changed file">
      grep -On 'render\s+json:.*error(?!.*status)' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No success false field in responses">
      grep -On 'success:\s*false' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

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

    [Play: Never Return 2xx with Errors](plays/never-return-2xx-with-errors.md)
  </pr_comment_template>

  <anti_pattern_sources>
    <source name="Connected Applications Controller" file="app/controllers/v0/profile/connected_applications_controller.rb:18" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/app/controllers/v0/profile/connected_applications_controller.rb#L18" />
    <source name="Digital Disputes Controller" file="modules/debts_api/app/controllers/debts_api/v0/digital_disputes_controller.rb:62" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/debts_api/app/controllers/debts_api/v0/digital_disputes_controller.rb#L62" />
  </anti_pattern_sources>

</agent_play>
-->

# Never Return 2xx with Errors

When a Rails controller renders JSON with error content but no explicit `status:` parameter, Rails defaults to 200 OK. This makes the error invisible to every automated system in the stack.

> [!CAUTION]
> Returning `200 OK` with an error body breaks **monitoring, retry logic, and caching**. Clients think the request succeeded.

## Why It Matters

When an error returns 200 OK, your CDN caches the error response and every user receives the cached error for up to five minutes, causing cascading failures. Your dashboards show 100% success even though 30% of requests are actually failing, so incidents go undetected. The client sees 200, assumes success, and does not retry -- the user's request fails silently while the UI shows "Success." APM sees 200 with no alert firing and no on-call engineer paged, so the issue is discovered hours later through user complaints. You lose visibility into real error rates and break every layer of automated protection you have.

## Guidance

The fix is straightforward: always include an explicit `status:` parameter on every `render json:` call in an error path. Use 4xx codes for client errors and 5xx for server errors. Use the standardized error format with an `errors` array of structured objects instead of ad-hoc hashes.

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

### Anti-Patterns from vets-api

#### Connected Applications Controller

##### Anti-Pattern

[app/controllers/v0/profile/connected_applications_controller.rb:18](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/app/controllers/v0/profile/connected_applications_controller.rb#L18)

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

##### Impact

Without explicit status code:

- Client thinks request succeeded (200 = success in HTTP per RFC 7231)
- Monitoring dashboards count this as successful request (inflated success rate metric)
- CDN/cache may cache this error response per HTTP caching rules
- Client retry logic won't trigger (only retries on 4xx/5xx per RFC 7231)
- APM tools don't classify as error (no alert fired)

With explicit status code:

- Client knows request failed and can show appropriate error UI
- Monitoring dashboards accurately track error rate
- CDN won't cache error responses
- Client retry logic triggers for transient failures

---

#### Digital Disputes Controller

##### Anti-Pattern

[modules/debts_api/app/controllers/debts_api/v0/digital_disputes_controller.rb:62](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/debts_api/app/controllers/debts_api/v0/digital_disputes_controller.rb#L62)

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

##### Impact

Without standardized format:

- Custom `success: false` field violates standardized error structure
- Clients must check both status code AND `success` field (redundant)
- `errors` hash format incompatible with standard parsers
- Inconsistent with other endpoints using standardized format

With standardized format:

- Structured format works with standard client libraries
- Status code alone conveys success/failure (no redundant `success` field)
- Field-level targeting tells client which form field has error
- Consistent error handling across all endpoints

## References

- [RFC 7231 Section 6.3](https://tools.ietf.org/html/rfc7231#section-6.3)
